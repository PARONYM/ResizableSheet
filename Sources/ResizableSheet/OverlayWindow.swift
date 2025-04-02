import SwiftUI

class OverlayWindow: PassThroughWindow {

    weak var ignoreView: UIView?

    init(ignoreView: UIView?) {
        self.ignoreView = ignoreView

        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// fix: hitTest return nil view
///
/// iOS 18 hit testing functionality differs from iOS 17
/// https://developer.apple.com/forums/thread/762292
public class PassThroughWindow: UIWindow {
    // Given the fact that hitTest being called twice for a single event is only based on observations we use a set of UIEvents to track handling rather than a more primitive flag
    private var encounteredEvents = Set<UIEvent>()
 
    // Based on observations, we have found that if an initial hitTest on UIWindow returns a view, then a 2nd hitTest is triggered
    // For hit testing to succeed both calls must return a view, if either test fails then this window will not handle the event
    // Prior to iOS 18 the views returned by super.hitTest on both calls were the same. However, under iOS 18 if the rootViewController of the window is a UIHostingController the 2nd hit test can return the rootViewController.view instead of the view returned in the first call.
    // This behavior breaks the original passthrough implementation that was working in earlier iOS versions since the 2nd hitTest would return nil, thus invalidating the 1st test
    // The solution to this difference in behavior is to return the value provided by super.hitTest on the 2nd test regardless of whether or not it is the rootViewController.view
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If we don't have a root controller or it does not have a view we are done and can exit
        guard let rootViewController, let rootView = rootViewController.view else { return nil }
 
        guard let event else {
            assertionFailure("hit testing without an event is not supported at this time")
            return super.hitTest(point, with: nil)
        }
 
        // We next check the base implementation for a hitView, if none is found we are done
        guard let hitView = super.hitTest(point, with: event) else {
            // defensive clearing of encountered events
            encounteredEvents.removeAll()
            return nil
        }
        if encounteredEvents.contains(event) {
            // We've already processed a hitTest for this event so we will allow it to proceed using the base implementation
            // We defensively clear all events from the cache since the assumptions about 2 calls for every event are only based on observations
            encounteredEvents.removeAll()
            return hitView
        } else if hitView == rootView {
            // The hitView is the rootView so we want to return nil and the system can pass through the event to other potential responders
            // iOS 18: This is the first hitTest being processed for this event
            // iOS 17: This is any hitTest being processed for the event, if assumptions about system behavior are correct this would be a first call as well and a 2nd call would never be fired
            return nil
        } else if #available(iOS 18, *) {
            // Since the discrepancy between 1st and 2nd hitTests only exists in iOS 18 and we are basing our knowledge about 2 calls for each event on observations we will limit the scope of our special handling
            // We have now encountered this event once and want the 2nd encounter to always return the view provided by the base implementation so we mark the event as encountered
            encounteredEvents.insert(event)
            return hitView
        } else {
            return hitView
        }
    }
}
