//! Overlay geometry, shared by the macOS panel and the tests.
//!
//! Coordinates match the Hammerspoon canvas: origin at the top left, y down.
//! The panel flips its view so these numbers can be drawn as they are.
#![cfg_attr(not(target_os = "macos"), allow(dead_code))]

use crate::engine::OverlaySpec;
use crate::model::OverlayRow;

pub const PAD: f64 = 16.0;
pub const TITLE_H: f64 = 28.0;
pub const ROW_H: f64 = 22.0;
pub const FOOTER_H: f64 = 22.0;
pub const GAP: f64 = 18.0;
pub const RADIUS: f64 = 14.0;
/// Points between the panel and the bottom of the visible screen frame.
pub const BOTTOM_MARGIN: f64 = 24.0;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TextRole {
    Title,
    Label,
    Hint,
    Footer,
}

#[derive(Clone, Debug, PartialEq)]
pub struct PlacedText {
    pub text: String,
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
    pub size: f64,
    pub role: TextRole,
}

#[derive(Clone, Debug, PartialEq)]
pub struct OverlayGeom {
    pub width: f64,
    pub height: f64,
    pub texts: Vec<PlacedText>,
}

pub fn layout(spec: &OverlaySpec) -> OverlayGeom {
    let columnar = !spec.columns.is_empty();
    let row_count = if columnar {
        spec.columns.iter().map(Vec::len).max().unwrap_or(0)
    } else {
        spec.rows.len()
    };
    let n_cols = if columnar { spec.columns.len() } else { 1 };
    let col_w = if columnar { 248.0 } else { 280.0 };
    let width = PAD * 2.0 + col_w * n_cols as f64 + GAP * (n_cols.saturating_sub(1) as f64);
    let height = PAD + TITLE_H + 6.0 + row_count as f64 * ROW_H + FOOTER_H + 8.0;
    let mut texts = vec![PlacedText {
        text: spec.title.clone(),
        x: PAD,
        y: PAD,
        w: width - PAD * 2.0,
        h: TITLE_H,
        size: 15.0,
        role: TextRole::Title,
    }];
    let top = PAD + TITLE_H + 4.0;
    if columnar {
        for (c, column) in spec.columns.iter().enumerate() {
            let x = PAD + c as f64 * (col_w + GAP);
            place_rows(&mut texts, column, x, top, col_w);
        }
    } else {
        place_rows(&mut texts, &spec.rows, PAD, top, col_w);
    }
    texts.push(PlacedText {
        text: spec.footer.clone(),
        x: PAD,
        y: height - FOOTER_H - 6.0,
        w: width - PAD * 2.0,
        h: FOOTER_H,
        size: 12.0,
        role: TextRole::Footer,
    });
    OverlayGeom {
        width,
        height,
        texts,
    }
}

fn place_rows(texts: &mut Vec<PlacedText>, rows: &[OverlayRow], x: f64, top: f64, col_w: f64) {
    let verb_w = (col_w * 0.56).floor();
    for (r, row) in rows.iter().enumerate() {
        let y = top + r as f64 * ROW_H;
        texts.push(PlacedText {
            text: row.label.clone(),
            x,
            y,
            w: verb_w,
            h: ROW_H,
            size: 13.0,
            role: TextRole::Label,
        });
        texts.push(PlacedText {
            text: row.hint.clone(),
            x: x + verb_w,
            y,
            w: col_w - verb_w,
            h: ROW_H,
            size: 13.0,
            role: TextRole::Hint,
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{Layer, OverlayRow};

    fn row(label: &str, hint: &str) -> OverlayRow {
        OverlayRow {
            label: label.to_string(),
            hint: hint.to_string(),
        }
    }

    #[test]
    fn chord_overlay_is_one_column() {
        let spec = OverlaySpec {
            layer: Layer::App,
            title: "Resize".to_string(),
            columns: Vec::new(),
            rows: vec![row("Wider", "→"), row("Taller", "↑")],
            footer: "esc cancels".to_string(),
        };
        let geom = layout(&spec);
        assert_eq!(geom.width, 312.0);
        assert_eq!(geom.height, 124.0);
        assert_eq!(geom.texts[1].role, TextRole::Label);
        assert_eq!(geom.texts[1].w, 156.0);
        assert_eq!(geom.texts[2].role, TextRole::Hint);
        assert_eq!(geom.texts[2].x, 16.0 + 156.0);
        assert_eq!(geom.texts.last().unwrap().text, "esc cancels");
    }

    #[test]
    fn layer_overlay_places_columns_side_by_side() {
        let spec = OverlaySpec {
            layer: Layer::Os,
            title: "Operating system".to_string(),
            columns: vec![
                vec![row("Focus", "←"), row("Move", "⇧←"), row("Zoom", "↩")],
                vec![row("Close", "Q")],
            ],
            rows: Vec::new(),
            footer: "space locks      esc clears".to_string(),
        };
        let geom = layout(&spec);
        assert_eq!(geom.width, 546.0);
        assert_eq!(geom.height, 146.0);
        let second = geom.texts.iter().find(|t| t.text == "Close").unwrap();
        assert_eq!(second.x, 16.0 + 248.0 + 18.0);
        assert_eq!(second.w, (248.0_f64 * 0.56).floor());
    }
}
