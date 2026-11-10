import SwiftUI
import UIKit

// MARK: - UIKit 3 ページ + 中央リセット

final class MonthPagerScrollViewController: UIViewController, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private var hostingControllers: [UIHostingController<MonthGridPageView>] = []

    var onSelectDay: (LocalDay) -> Void = { _ in }
    var onMonthCommitted: (YearMonth) -> Void = { _ in }

    private(set) var lastAppliedVisibleMonth: YearMonth?
    private var isRecentering = false
    private var needsInitialCenter = true
    private var latestModels: (MonthGridPageModel, MonthGridPageModel, MonthGridPageModel)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrollView.backgroundColor = .clear
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.bounces = true
        scrollView.delegate = self
        view.addSubview(scrollView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutScrollContent()
    }

    func updatePages(
        prev: MonthGridPageModel,
        center: MonthGridPageModel,
        next: MonthGridPageModel,
        visibleMonth: YearMonth,
        forceRecenter: Bool
    ) {
        latestModels = (prev, center, next)
        lastAppliedVisibleMonth = visibleMonth

        applyModelsIfReady()

        if forceRecenter {
            recenterScroll(animated: false)
        }
    }

    private func layoutScrollContent() {
        let width = view.bounds.width
        let height = view.bounds.height
        guard width > 0, height > 0 else { return }

        scrollView.frame = view.bounds
        scrollView.contentSize = CGSize(width: width * 3, height: height)

        ensureHostingControllers()
        applyModelsIfReady()

        for (index, hosting) in hostingControllers.enumerated() {
            hosting.view.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: height)
        }

        if needsInitialCenter {
            scrollView.contentOffset = CGPoint(x: width, y: 0)
            needsInitialCenter = false
        }
    }

    private func ensureHostingControllers() {
        while hostingControllers.count < 3 {
            let placeholder = MonthGridPageModel(
                month: .current(),
                days: [],
                linesByDay: [:],
                selectedDay: nil,
                today: LocalDay(Date())
            )
            let hosting = UIHostingController(
                rootView: MonthGridPageView(model: placeholder, onSelectDay: onSelectDay)
            )
            hosting.view.backgroundColor = .clear
            addChild(hosting)
            scrollView.addSubview(hosting.view)
            hosting.didMove(toParent: self)
            hostingControllers.append(hosting)
        }
    }

    private func applyModelsIfReady() {
        guard let models = latestModels, hostingControllers.count == 3 else { return }
        let pages = [models.0, models.1, models.2]
        for (index, model) in pages.enumerated() {
            hostingControllers[index].rootView = MonthGridPageView(model: model, onSelectDay: onSelectDay)
        }
    }

    private func recenterScroll(animated: Bool) {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        isRecentering = true
        scrollView.setContentOffset(CGPoint(x: width, y: 0), animated: animated)
        isRecentering = false
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settleIfNeeded(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            settleIfNeeded(scrollView)
        }
    }

    private func settleIfNeeded(_ scrollView: UIScrollView) {
        guard !isRecentering else { return }
        guard let month = lastAppliedVisibleMonth else { return }

        let width = scrollView.bounds.width
        guard width > 0 else { return }

        let page = Int(round(scrollView.contentOffset.x / width))
        guard page != 1 else { return }

        let newMonth = month.addingMonths(page == 0 ? -1 : 1)
        lastAppliedVisibleMonth = newMonth
        recenterScroll(animated: false)
        onMonthCommitted(newMonth)
    }
}

// MARK: - SwiftUI bridge

struct MonthUIKitScrollPager: UIViewControllerRepresentable {
    let prev: MonthGridPageModel
    let center: MonthGridPageModel
    let next: MonthGridPageModel
    @Binding var visibleMonth: YearMonth
    var onMonthCommitted: (YearMonth) -> Void
    var onSelectDay: (LocalDay) -> Void

    func makeUIViewController(context: Context) -> MonthPagerScrollViewController {
        let controller = MonthPagerScrollViewController()
        wireCallbacks(to: controller)
        return controller
    }

    func updateUIViewController(_ controller: MonthPagerScrollViewController, context: Context) {
        wireCallbacks(to: controller)
        let forceRecenter = controller.lastAppliedVisibleMonth.map { $0 != visibleMonth } ?? false
        controller.updatePages(
            prev: prev,
            center: center,
            next: next,
            visibleMonth: visibleMonth,
            forceRecenter: forceRecenter
        )
    }

    private func wireCallbacks(to controller: MonthPagerScrollViewController) {
        controller.onSelectDay = onSelectDay
        controller.onMonthCommitted = { month in
            visibleMonth = month
            onMonthCommitted(month)
        }
    }
}
