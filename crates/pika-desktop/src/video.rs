use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;

use pika_core::VideoFrameReceiver;
use pika_media::tracks::video_params;

use crate::app_manager::AppManager;
use crate::video_shader::VideoShaderProgram;

/// Receives decrypted H.264 NALUs from Rust core via the `VideoFrameReceiver` callback,
/// decodes them with openh264, and stores the latest RGBA frame for iced rendering.
struct DesktopVideoReceiver {
    latest_frame: Arc<Mutex<Option<DecodedFrame>>>,
    generation: Arc<AtomicU64>,
}

#[derive(Clone)]
pub struct DecodedFrame {
    pub width: u32,
    pub height: u32,
    pub rgba: Vec<u8>,
}

impl DesktopVideoReceiver {
    fn new(
        latest_frame: Arc<Mutex<Option<DecodedFrame>>>,
        generation: Arc<AtomicU64>,
    ) -> Self {
        Self {
            latest_frame,
            generation,
        }
    }
}

impl VideoFrameReceiver for DesktopVideoReceiver {
    fn on_video_frame(&self, _call_id: String, payload: Vec<u8>) {
        let decoded = decode_h264_to_rgba(&payload);
        if let Some(frame) = decoded {
            if let Ok(mut slot) = self.latest_frame.lock() {
                *slot = Some(frame);
                self.generation.fetch_add(1, Ordering::Relaxed);
            }
        }
    }
}

fn decode_h264_to_rgba(annexb: &[u8]) -> Option<DecodedFrame> {
    use openh264::formats::YUVSource;

    thread_local! {
        static DECODER: std::cell::RefCell<Option<openh264::decoder::Decoder>> =
            std::cell::RefCell::new(openh264::decoder::Decoder::new().ok());
    }

    DECODER.with(|cell| {
        let mut decoder_opt = cell.borrow_mut();
        let decoder = decoder_opt.as_mut()?;
        let yuv = decoder.decode(annexb).ok()??;

        let (width, height) = yuv.dimensions();
        let mut rgba = vec![0u8; width * height * 4];
        yuv.write_rgba8(&mut rgba);

        Some(DecodedFrame {
            width: width as u32,
            height: height as u32,
            rgba,
        })
    })
}


/// Captures from the system camera, encodes to H.264, and pushes to Rust core.
struct CaptureThread {
    stop: Arc<AtomicBool>,
    handle: Option<thread::JoinHandle<()>>,
}

impl CaptureThread {
    fn start(manager: AppManager, camera_error: Arc<Mutex<Option<String>>>) -> Self {
        let stop = Arc::new(AtomicBool::new(false));
        let stop_flag = stop.clone();

        let handle = thread::spawn(move || {
            Self::capture_loop(manager, stop_flag, camera_error);
        });

        Self {
            stop,
            handle: Some(handle),
        }
    }

    fn stop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(h) = self.handle.take() {
            let _ = h.join();
        }
    }

    fn capture_loop(
        manager: AppManager,
        stop: Arc<AtomicBool>,
        camera_error: Arc<Mutex<Option<String>>>,
    ) {
        use nokhwa::pixel_format::RgbFormat;
        use nokhwa::utils::{
            CameraIndex, RequestedFormat, RequestedFormatType, Resolution,
        };
        use nokhwa::Camera;
        use openh264::formats::YUVBuffer;

        let set_error = |msg: String| {
            if let Ok(mut slot) = camera_error.lock() {
                *slot = Some(msg);
            }
        };

        // Request target resolution — AbsoluteHighestResolution may select 4K which is too slow
        let format = RequestedFormat::new::<RgbFormat>(
            RequestedFormatType::HighestResolution(Resolution::new(
                video_params::WIDTH,
                video_params::HEIGHT,
            )),
        );
        let mut camera = match Camera::new(CameraIndex::Index(0), format) {
            Ok(c) => c,
            Err(e) => {
                set_error(format!(
                    "Camera open failed: {e}. Check /dev/video0 permissions (try: sudo usermod -aG video $USER)"
                ));
                return;
            }
        };
        if let Err(e) = camera.open_stream() {
            set_error(format!("Camera stream failed: {e}"));
            return;
        }

        let mut encoder: openh264::encoder::Encoder = match openh264::encoder::Encoder::new() {
            Ok(e) => e,
            Err(e) => {
                set_error(format!("H.264 encoder init failed: {e}"));
                return;
            }
        };

        let mut frame_count = 0u64;

        while !stop.load(Ordering::Relaxed) {
            // camera.frame() blocks until the next frame is available,
            // so the camera hardware naturally paces the loop at ~30fps.
            let buf = match camera.frame() {
                Ok(f) => f,
                Err(_) => continue,
            };

            // Decode camera buffer to RGB
            let rgb_image = match buf.decode_image::<RgbFormat>() {
                Ok(img) => img,
                Err(_) => continue,
            };

            let width = rgb_image.width() as usize;
            let height = rgb_image.height() as usize;
            let rgb_bytes = rgb_image.as_raw();

            // Convert RGB to YUV420 for openh264
            let yuv = rgb_to_yuv420(rgb_bytes, width, height);
            let yuv_buf = YUVBuffer::from_vec(yuv, width, height);

            // Force IDR periodically so late joiners get SPS/PPS
            if frame_count.is_multiple_of(video_params::KEYFRAME_INTERVAL as u64) {
                encoder.force_intra_frame();
            }
            frame_count += 1;

            // Encode
            let encoded: openh264::encoder::EncodedBitStream<'_> = match encoder.encode(&yuv_buf) {
                Ok(e) => e,
                Err(_) => continue,
            };

            // Collect Annex B bitstream
            let annexb = encoded.to_vec();

            if !annexb.is_empty() {
                manager.send_video_frame(annexb);
            }
        }

        let _ = camera.stop_stream();
    }
}

fn rgb_to_yuv420(rgb: &[u8], width: usize, height: usize) -> Vec<u8> {
    let y_size = width * height;
    let uv_size = (width / 2) * (height / 2);
    let mut yuv = vec![0u8; y_size + uv_size * 2];

    let (y_plane, uv_planes) = yuv.split_at_mut(y_size);
    let (u_plane, v_plane) = uv_planes.split_at_mut(uv_size);

    for row in 0..height {
        for col in 0..width {
            let idx = (row * width + col) * 3;
            if idx + 2 >= rgb.len() {
                break;
            }
            let r = rgb[idx] as f32;
            let g = rgb[idx + 1] as f32;
            let b = rgb[idx + 2] as f32;

            y_plane[row * width + col] =
                (0.299 * r + 0.587 * g + 0.114 * b).clamp(0.0, 255.0) as u8;

            if row % 2 == 0 && col % 2 == 0 {
                let uv_idx = (row / 2) * (width / 2) + col / 2;
                u_plane[uv_idx] =
                    (-0.169 * r - 0.331 * g + 0.500 * b + 128.0).clamp(0.0, 255.0) as u8;
                v_plane[uv_idx] =
                    (0.500 * r - 0.419 * g - 0.081 * b + 128.0).clamp(0.0, 255.0) as u8;
            }
        }
    }

    yuv
}

/// Manages the full desktop video pipeline lifecycle.
pub struct DesktopVideoPipeline {
    latest_frame: Arc<Mutex<Option<DecodedFrame>>>,
    generation: Arc<AtomicU64>,
    camera_error: Arc<Mutex<Option<String>>>,
    capture_thread: Option<CaptureThread>,
    is_active: bool,
    /// Track the last generation we saw a new frame, for staleness detection.
    last_seen_generation: u64,
    /// Monotonic instant of the last new remote frame.
    last_frame_instant: Option<std::time::Instant>,
}

impl DesktopVideoPipeline {
    pub fn new() -> Self {
        Self {
            latest_frame: Arc::new(Mutex::new(None)),
            generation: Arc::new(AtomicU64::new(0)),
            camera_error: Arc::new(Mutex::new(None)),
            capture_thread: None,
            is_active: false,
            last_seen_generation: 0,
            last_frame_instant: None,
        }
    }

    pub fn camera_error(&self) -> Option<String> {
        self.camera_error.lock().ok()?.clone()
    }

    pub fn start(&mut self, manager: &AppManager) {
        if self.is_active {
            return;
        }
        self.is_active = true;

        // Clear any previous camera error
        if let Ok(mut slot) = self.camera_error.lock() {
            *slot = None;
        }

        let receiver =
            DesktopVideoReceiver::new(self.latest_frame.clone(), self.generation.clone());
        manager.set_video_frame_receiver(Box::new(receiver));

        self.capture_thread =
            Some(CaptureThread::start(manager.clone(), self.camera_error.clone()));
    }

    pub fn stop(&mut self) {
        if !self.is_active {
            return;
        }
        self.is_active = false;

        if let Some(mut ct) = self.capture_thread.take() {
            ct.stop();
        }
        if let Ok(mut slot) = self.latest_frame.lock() {
            *slot = None;
        }
    }

    /// Stop only the camera capture thread (when camera is toggled off) but keep
    /// the decoder/receiver active so remote frames still display.
    fn stop_capture(&mut self) {
        if let Some(mut ct) = self.capture_thread.take() {
            ct.stop();
        }
    }

    fn start_capture(&mut self, manager: &AppManager) {
        if self.capture_thread.is_some() {
            return;
        }
        self.capture_thread =
            Some(CaptureThread::start(manager.clone(), self.camera_error.clone()));
    }

    /// Whether at least one video frame has been decoded and is not stale.
    pub fn has_video(&self) -> bool {
        self.generation.load(Ordering::Relaxed) > 0
            && self.last_frame_instant.is_some_and(|t| t.elapsed().as_secs_f64() < 1.0)
    }

    /// Call periodically (e.g. on each video tick) to update staleness tracking
    /// and clear the decoded frame if no new frames arrive for 1 second.
    pub fn check_staleness(&mut self) {
        let gen = self.generation.load(Ordering::Relaxed);
        if gen != self.last_seen_generation {
            self.last_seen_generation = gen;
            self.last_frame_instant = Some(std::time::Instant::now());
        } else if let Some(t) = self.last_frame_instant {
            if t.elapsed().as_secs_f64() > 1.0 {
                // Remote stopped sending — clear the frame
                if let Ok(mut slot) = self.latest_frame.lock() {
                    *slot = None;
                }
                self.last_frame_instant = None;
            }
        }
    }

    /// Create a shader program for rendering the video via a persistent GPU texture.
    pub fn shader_program(&self) -> VideoShaderProgram {
        VideoShaderProgram::new(self.latest_frame.clone(), self.generation.clone())
    }

    pub fn sync_with_call(&mut self, call: Option<&pika_core::CallState>, manager: &AppManager) {
        match call {
            Some(call) if call.is_video_call && call.is_live => {
                if !self.is_active {
                    self.start(manager);
                }
                // Pause/resume camera capture based on camera enabled state
                if call.is_camera_enabled {
                    self.start_capture(manager);
                } else {
                    self.stop_capture();
                }
            }
            _ => {
                self.stop();
            }
        }
    }
}
