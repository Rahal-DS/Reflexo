//
//  CustomStacks.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 10/10/2025.
//

import SwiftUI

/// A vertical layout that forces all children to share the **same height**:
/// the maximum intrinsic height among the arranged subviews at the given width.
///
/// `EqualHeightVStack` measures all subviews at the available width (after
/// subtracting `horizontalPadding * 2`), finds the tallest, and then places
/// every child with that height. This is useful for creating uniformly tall
/// rows/cards that still adapt to dynamic content and device width.
///
/// ### Behavior
/// - Children are measured with a width of `availableWidth = containerWidth - (horizontalPadding * 2)`.
/// - The tallest child's height becomes the **row height** for all children.
/// - Spacing between rows is controlled by ``spacing``.
/// - Left/right insets are controlled by ``horizontalPadding`` (visual layout; not added as empty views).
///
/// ### Requirements
/// - Uses the SwiftUI `Layout` protocol (iOS 16+, macOS 13+, etc.).
///
/// ### Example
/// ```swift
/// EqualHeightVStack(spacing: 12, horizontalPadding: 24) {
///     Text("Short")
///         .frame(maxWidth: .infinity)
///         .padding()
///         .background(.blue.opacity(0.2))
///
///     VStack(alignment: .leading) {
///         Text("A much longer block of text that wraps onto multiple lines.")
///         Text("Secondary line")
///     }
///     .frame(maxWidth: .infinity, alignment: .leading)
///     .padding()
///     .background(.green.opacity(0.2))
/// }
/// .padding(.horizontal) // outer page padding if desired
/// ```
///
/// - Note: If you need per-row horizontal padding on the laid-out children
///   themselves, apply it inside each child view; `horizontalPadding` only
///   reduces the measuring/placement width.
/// - Important: Very large child counts may cause extra measuring work,
///   since each subview is measured twice (once in `sizeThatFits`, once in
///   `placeSubviews`). Cache custom sizes in your subviews if performance matters.
struct EqualHeightVStack: Layout {
    var spacing: CGFloat = 16   // vertical spacing
    var horizontalPadding: CGFloat = 20
    
    /// Computes the size needed to fit all subviews using the max child height.
    ///
    /// - Parameters:
    ///   - proposal: The proposed size from the parent.
    ///   - subviews: The subviews to be arranged.
    ///   - cache: Unused in this implementation.
    /// - Returns: A `CGSize` whose width honors the proposal (if provided) and whose
    ///   height equals `maxHeight * count + spacing * (count - 1)`.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // available width = proposal minus padding
        let availableWidth = (proposal.width ?? 0) - horizontalPadding * 2
        
        // measure all children at that width
        let heights = subviews.map { subview in
            subview.sizeThatFits(.init(width: availableWidth, height: nil)).height
        }
        let maxHeight = heights.max() ?? 0
        
        // total height = maxHeight per child + spacing
        let totalHeight = CGFloat(subviews.count) * maxHeight
        + CGFloat(max(0, subviews.count - 1)) * spacing
        
        return CGSize(width: proposal.width ?? availableWidth,
                      height: totalHeight)
    }
    
    /// Places each subview full-width with the same calculated height.
    ///
    /// - Parameters:
    ///   - bounds: The container rectangle provided by the parent.
    ///   - proposal: The proposed size from the parent.
    ///   - subviews: The subviews to be arranged.
    ///   - cache: Unused in this implementation.
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let availableWidth = bounds.width - horizontalPadding * 2
        
        // find tallest subview
        let heights = subviews.map { $0.sizeThatFits(.init(width: availableWidth, height: nil)).height }
        let maxHeight = heights.max() ?? 0
        
        // place each subview full width with equal height
        var y = bounds.minY
        for subview in subviews {
            subview.place(
                at: CGPoint(x: bounds.midX, y: y + maxHeight / 2),
                anchor: .center,
                proposal: .init(width: availableWidth, height: maxHeight)
            )
            y += maxHeight + spacing
        }
    }
}
