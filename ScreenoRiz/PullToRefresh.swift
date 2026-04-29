//
//  PullToRefresh.swift
//  ScreenoRiz
//
//  UIKit bridge for pull-to-refresh. SwiftUI's GeometryReader doesn't fire
//  during rubber-banding (the scroll view transforms its content layer instead
//  of re-laying it out), so pure-SwiftUI offset tracking can't detect a pull.
//  UIRefreshControl handles all of that reliably; we just hide its spinner.
//

import SwiftUI

struct UIKitRefreshControl: UIViewRepresentable {
    @Binding var isRefreshing: Bool
    let onRefresh: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = uiView.firstScrollViewAncestor() else { return }
            if scrollView.refreshControl == nil {
                let control = UIRefreshControl()
                control.tintColor = .clear          // hide native spinner
                control.addTarget(context.coordinator,
                                  action: #selector(Coordinator.handleRefresh),
                                  for: .valueChanged)
                scrollView.refreshControl = control
            }
            if !isRefreshing {
                scrollView.refreshControl?.endRefreshing()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        let parent: UIKitRefreshControl
        init(_ parent: UIKitRefreshControl) { self.parent = parent }

        @objc func handleRefresh() {
            parent.isRefreshing = true
            parent.onRefresh()
        }
    }
}

private extension UIView {
    func firstScrollViewAncestor() -> UIScrollView? {
        var v: UIView? = superview
        while let candidate = v {
            if let sv = candidate as? UIScrollView { return sv }
            v = candidate.superview
        }
        return nil
    }
}
