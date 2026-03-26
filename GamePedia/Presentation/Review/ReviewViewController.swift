import UIKit

// MARK: - ReviewViewController

final class ReviewViewController: BaseViewController<ReviewRootView, ReviewState> {

    // MARK: Properties
    private let viewModel: ReviewViewModel

    // Called after successful submission, so GameDetail can reload
    var onReviewSubmitted: (() -> Void)?

    // MARK: Init
    init(rootView: ReviewRootView, viewModel: ReviewViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
    }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    // MARK: Setup

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "리뷰 작성"
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    private func setupActions() {
        rootView.reviewTextView.delegate = self
        rootView.spoilerSwitch.addTarget(self, action: #selector(spoilerSwitchToggled), for: .valueChanged)
        rootView.submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        rootView.starRatingView.onRatingChanged = { [weak self] rating in
            self?.viewModel.send(.ratingChanged(rating))
        }

        // Dismiss keyboard on tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: ViewModel Binding

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.render(state) }
        }
    }

    override func render(_ state: ReviewState) {
        rootView.render(state)

        if state.didSubmitSuccessfully {
            onReviewSubmitted?()
            navigationController?.popViewController(animated: true)
        }

        if let error = state.errorMessage {
            showErrorAlert(message: error)
        }
    }

    // MARK: Actions

    @objc private func spoilerSwitchToggled(_ sender: UISwitch) {
        viewModel.send(.spoilerToggled(sender.isOn))
    }

    @objc private func didTapSubmit() {
        viewModel.send(.didTapSubmit)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: Helpers

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate

extension ReviewViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.send(.textChanged(textView.text))
    }
}
