import UIKit

// MARK: - ReviewViewController

final class ReviewViewController: BaseViewController<ReviewRootView, ReviewState> {

    // MARK: Properties
    private let viewModel: ReviewViewModel
    private let defaultSubmitAreaInset: CGFloat = 0
    private lazy var backgroundTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        gestureRecognizer.cancelsTouchesInView = false
        gestureRecognizer.delegate = self
        return gestureRecognizer
    }()

    // Called after successful submission, so GameDetail can reload
    var onReviewSubmitted: (() -> Void)?

    // MARK: Init
    init(rootView: ReviewRootView, viewModel: ReviewViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        hidesBottomBarWhenPushed = true
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
    }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        setupKeyboardObservers()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Setup

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = viewModel.state.navigationTitle
            navigationItem.largeTitleDisplayMode = .never
        }
        navigationItem.rightBarButtonItems = nil
    }

    private func setupActions() {
        rootView.reviewTextView.delegate = self
        rootView.submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        rootView.submitButton.addTarget(self, action: #selector(didTapSubmitTouchDown), for: .touchDown)
        rootView.submitButton.addTarget(self, action: #selector(didTapSubmit), for: .primaryActionTriggered)
        rootView.deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        rootView.starRatingView.onRatingChanged = { [weak self] rating in
            self?.viewModel.send(.ratingChanged(rating))
        }

        rootView.scrollView.addGestureRecognizer(backgroundTapGestureRecognizer)
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    // MARK: ViewModel Binding

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.render(state) }
        }

        print("[ReviewSubmit] bindViewModel initialState submitEnabled=\(viewModel.state.submitEnabled) rating=\(viewModel.state.rating) trimmedCount=\(viewModel.state.trimmedReviewText.count)")
        render(viewModel.state)
    }

    override func render(_ state: ReviewState) {
        navigationItem.title = state.navigationTitle
        rootView.render(state)

        if state.didSubmitSuccessfully {
            onReviewSubmitted?()
            navigationController?.popViewController(animated: true)
        }

        if state.didDeleteSuccessfully {
            onReviewSubmitted?()
            navigationController?.popViewController(animated: true)
        }

        if let error = state.errorMessage {
            showErrorAlert(message: error)
        }
    }

    // MARK: Actions

    @objc private func didTapSubmitTouchDown() {
        print("[ReviewSubmit] buttonTouchDown isEnabled=\(rootView.submitButton.isEnabled) isUserInteractionEnabled=\(rootView.submitButton.isUserInteractionEnabled)")
    }

    @objc private func didTapDelete() {
        let alert = UIAlertController(
            title: L10n.Review.Alert.deleteTitle,
            message: L10n.Review.Alert.deleteMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Review.Button.delete, style: .destructive) { [weak self] _ in
            print("[ReviewDelete] ViewController forwarded delete action")
            self?.viewModel.send(.didTapDelete)
        })
        present(alert, animated: true)
    }

    @objc private func didTapSubmit() {
        print("[ReviewSubmit] buttonTapped isEnabled=\(rootView.submitButton.isEnabled) isUserInteractionEnabled=\(rootView.submitButton.isUserInteractionEnabled) submitEnabled=\(viewModel.state.submitEnabled) rating=\(viewModel.state.rating) trimmedCount=\(viewModel.state.trimmedReviewText.count)")
        view.endEditing(true)
        print("[ReviewSubmit] ViewController forwarded submit action")
        viewModel.send(.didTapSubmit)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        updateSubmitAreaInset(
            to: defaultSubmitAreaInset,
            notification: notification
        )
    }

    @objc private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let keyboardFrameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }

        let keyboardFrame = view.convert(keyboardFrameValue.cgRectValue, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY - view.safeAreaInsets.bottom)
        updateSubmitAreaInset(
            to: overlap,
            notification: notification
        )
    }

    private func updateSubmitAreaInset(to inset: CGFloat, notification: Notification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curveRawValue = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue
            ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        let options = UIView.AnimationOptions(rawValue: UInt(curveRawValue << 16))

        rootView.setSubmitAreaBottomInset(inset)
        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: Helpers

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: L10n.Common.Error.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default))
        present(alert, animated: true)
    }
}

extension ReviewViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }

        if let touchedView = touch.view, touchedView.isDescendant(of: rootView.submitButton) {
            return false
        }

        return true
    }
}

// MARK: - UITextViewDelegate

extension ReviewViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        rootView.setReviewTextInputFocused(true)
    }

    func textViewDidChange(_ textView: UITextView) {
        viewModel.send(.textChanged(textView.text))
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        rootView.setReviewTextInputFocused(false)
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard let textRange = Range(range, in: textView.text) else { return true }
        let updatedText = textView.text.replacingCharacters(in: textRange, with: text)
        let cappedText = String(updatedText.prefix(viewModel.state.maxChars))

        guard updatedText.count > viewModel.state.maxChars else { return true }

        textView.text = cappedText
        viewModel.send(.textChanged(cappedText))
        return false
    }
}
