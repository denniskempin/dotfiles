//! Non-activating overlay panel. AppKit coordinates grow upward, so the view
//! is flipped and then painted with the top-left geometry from `overlay`.

use crate::engine::OverlaySpec;
use crate::model::Layer;
use crate::overlay::{self, OverlayGeom, TextRole};
use objc2::rc::Retained;
use objc2::runtime::AnyObject;
use objc2::{define_class, msg_send, DefinedClass, MainThreadMarker};
use objc2_app_kit::{
    NSBackingStoreType, NSBezierPath, NSColor, NSFont, NSFontAttributeName,
    NSForegroundColorAttributeName, NSMutableParagraphStyle, NSPanel,
    NSParagraphStyleAttributeName, NSScreen, NSStringDrawing, NSTextAlignment, NSView,
    NSWindowCollectionBehavior, NSWindowLevel, NSWindowStyleMask,
};
use objc2_core_foundation::{CGPoint, CGRect, CGSize};
use objc2_core_graphics::kCGOverlayWindowLevel;
use objc2_foundation::{NSAttributedStringKey, NSDictionary, NSRect, NSString};
use std::cell::RefCell;

struct ViewState {
    spec: RefCell<Option<OverlaySpec>>,
}

define_class!(
    #[unsafe(super(NSView))]
    #[thread_kind = MainThreadOnly]
    #[ivars = ViewState]
    struct OverlayView;

    impl OverlayView {
        #[unsafe(method(isFlipped))]
        fn is_flipped(&self) -> bool {
            true
        }

        #[unsafe(method(drawRect:))]
        fn draw_rect(&self, _dirty: NSRect) {
            self.paint();
        }
    }
);

impl OverlayView {
    fn new(mtm: MainThreadMarker) -> Retained<Self> {
        let this = Self::alloc(mtm).set_ivars(ViewState {
            spec: RefCell::new(None),
        });
        let view: Retained<Self> = unsafe { msg_send![super(this), initWithFrame: CGRect::ZERO] };
        view
    }

    fn set_spec(&self, spec: OverlaySpec) {
        *self.ivars().spec.borrow_mut() = Some(spec);
        self.setNeedsDisplay(true);
    }

    fn paint(&self) {
        let spec = self.ivars().spec.borrow().clone();
        let Some(spec) = spec else {
            return;
        };
        let geom = overlay::layout(&spec);
        let bounds = self.bounds();
        let background = NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(
            bounds,
            overlay::RADIUS,
            overlay::RADIUS,
        );
        NSColor::colorWithSRGBRed_green_blue_alpha(
            0x1C as f64 / 255.0,
            0x1C as f64 / 255.0,
            0x1E as f64 / 255.0,
            0.94,
        )
        .setFill();
        background.fill();

        let inset = NSRect::new(
            CGPoint::new(bounds.origin.x + 0.5, bounds.origin.y + 0.5),
            CGSize::new(
                (bounds.size.width - 1.0).max(0.0),
                (bounds.size.height - 1.0).max(0.0),
            ),
        );
        let border = NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(
            inset,
            overlay::RADIUS,
            overlay::RADIUS,
        );
        border.setLineWidth(1.0);
        NSColor::colorWithWhite_alpha(1.0, 0.08).setStroke();
        border.stroke();

        let accent = accent(spec.layer);
        for text in &geom.texts {
            draw_text(text, &accent);
        }
    }
}

fn accent(layer: Layer) -> Retained<NSColor> {
    let (r, g, b) = match layer {
        Layer::Os => (0x8E, 0xBE, 0xFF),
        Layer::App => (0xE7, 0xC2, 0x7A),
    };
    NSColor::colorWithSRGBRed_green_blue_alpha(
        r as f64 / 255.0,
        g as f64 / 255.0,
        b as f64 / 255.0,
        1.0,
    )
}

fn draw_text(text: &overlay::PlacedText, accent: &NSColor) {
    if text.text.is_empty() {
        return;
    }
    let label = NSColor::colorWithWhite_alpha(0.92, 1.0);
    let footer = NSColor::colorWithWhite_alpha(0.45, 1.0);
    let color: &NSColor = match text.role {
        TextRole::Title | TextRole::Hint => accent,
        TextRole::Label => &label,
        TextRole::Footer => &footer,
    };
    let font = ui_font(text.size);
    let style = NSMutableParagraphStyle::new();
    if text.role == TextRole::Hint {
        style.setAlignment(NSTextAlignment::Right);
    }
    let keys: [&NSAttributedStringKey; 3] = [
        unsafe { NSFontAttributeName },
        unsafe { NSForegroundColorAttributeName },
        unsafe { NSParagraphStyleAttributeName },
    ];
    let objects: [&AnyObject; 3] = [as_object(&*font), as_object(color), as_object(&*style)];
    let attrs = NSDictionary::from_slices(&keys, &objects);
    let rect = NSRect::new(CGPoint::new(text.x, text.y), CGSize::new(text.w, text.h));
    unsafe {
        NSString::from_str(&text.text).drawInRect_withAttributes(rect, Some(&attrs));
    }
}

fn ui_font(size: f64) -> Retained<NSFont> {
    let name = NSString::from_str(".AppleSystemUIFont");
    NSFont::fontWithName_size(&name, size).unwrap_or_else(|| NSFont::systemFontOfSize(size))
}

fn as_object(obj: &impl objc2::Message) -> &AnyObject {
    unsafe { &*(obj as *const _ as *const AnyObject) }
}

pub struct OverlayWindows {
    panel: Option<Retained<NSPanel>>,
    view: Option<Retained<OverlayView>>,
}

impl OverlayWindows {
    pub fn new() -> Self {
        Self {
            panel: None,
            view: None,
        }
    }

    pub fn show(&mut self, mtm: MainThreadMarker, spec: &OverlaySpec) {
        let Some(screen) = NSScreen::mainScreen(mtm) else {
            return;
        };
        let geom = overlay::layout(spec);
        let frame = screen_frame(&screen, &geom);
        let view = if let Some(view) = &self.view {
            view.clone()
        } else {
            let view = OverlayView::new(mtm);
            self.view = Some(view.clone());
            view
        };
        view.set_spec(spec.clone());
        view.setFrame(NSRect::new(
            CGPoint::ZERO,
            CGSize::new(geom.width, geom.height),
        ));
        if let Some(panel) = &self.panel {
            panel.setFrame_display(frame, true);
            panel.orderFrontRegardless();
            return;
        }
        let style = NSWindowStyleMask::Borderless | NSWindowStyleMask::NonactivatingPanel;
        let panel = NSPanel::initWithContentRect_styleMask_backing_defer(
            NSPanel::alloc(mtm),
            frame,
            style,
            NSBackingStoreType::Buffered,
            false,
        );
        panel.setStyleMask(style);
        panel.setLevel(kCGOverlayWindowLevel as NSWindowLevel);
        panel.setCollectionBehavior(
            NSWindowCollectionBehavior::CanJoinAllSpaces
                | NSWindowCollectionBehavior::Stationary
                | NSWindowCollectionBehavior::IgnoresCycle,
        );
        panel.setIgnoresMouseEvents(true);
        panel.setHidesOnDeactivate(false);
        panel.setOpaque(false);
        panel.setHasShadow(false);
        panel.setFloatingPanel(true);
        panel.setBecomesKeyOnlyIfNeeded(true);
        panel.setBackgroundColor(Some(&NSColor::clearColor()));
        let ns_view: &NSView = &*view;
        panel.setContentView(Some(ns_view));
        panel.orderFrontRegardless();
        self.panel = Some(panel);
    }

    pub fn hide(&mut self) {
        if let Some(panel) = &self.panel {
            panel.orderOut(None);
        }
    }
}

fn screen_frame(screen: &NSScreen, geom: &OverlayGeom) -> NSRect {
    let frame = screen.visibleFrame();
    NSRect::new(
        CGPoint::new(
            frame.origin.x + (frame.size.width - geom.width) / 2.0,
            frame.origin.y + overlay::BOTTOM_MARGIN,
        ),
        CGSize::new(geom.width, geom.height),
    )
}
