use iced::widget::{container, text};
use iced::{Alignment, Element, Length, Theme};

use crate::theme;

/// Renders a circular avatar with the first letter of the display name.
/// Falls back to the first letter of the npub if name is empty.
pub fn avatar_circle<'a, M: 'a>(
    name: Option<&str>,
    npub: &str,
    size: f32,
) -> Element<'a, M, Theme> {
    let initial = name
        .and_then(|n| n.trim().chars().next())
        .or_else(|| npub.chars().next())
        .unwrap_or('?')
        .to_uppercase()
        .to_string();

    container(
        text(initial)
            .size(size * 0.45)
            .color(theme::TEXT_PRIMARY)
            .center(),
    )
    .width(Length::Fixed(size))
    .height(Length::Fixed(size))
    .align_x(Alignment::Center)
    .align_y(Alignment::Center)
    .style(theme::avatar_container_style)
    .into()
}
