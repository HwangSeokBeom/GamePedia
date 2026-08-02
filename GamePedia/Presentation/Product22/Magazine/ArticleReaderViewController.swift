import Kingfisher
import SafariServices
import UIKit

// MARK: - ArticleReaderViewController
//
// The magazine reader.
//
// There is deliberately no web view in this screen. The body is rendered by
// `ArticleMarkdownRenderer` into an `NSAttributedString` and displayed in a
// `UITextView` with editing and data detectors off, so there is no script
// engine, no DOM and no automatic link detection to subvert.
//
// The hero image comes from the typed `ArticleCard` the reader was opened
// from, never from the article detail — `PublicArticle.heroImage` is untyped
// in the contract, so a hero read from there would be a guess. An article
// opened without a card simply has no hero.

final class ArticleReaderViewController: UIViewController {

    // MARK: State

    private let slug: String
    /// The typed card this reader was opened from, when there was one. Carries
    /// the rights-reviewed hero and the canonical related games.
    private let card: ArticleCard?
    private let repository: any MagazineRepositing
    private let onOpenCatalogGame: ((CatalogGameID) -> Void)?

    private var loadTask: Task<Void, Never>?
    private var sources: [ArticleSource] = []

    // MARK: Views

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let heroImageView = UIImageView()
    private let heroPlaceholderLabel = UILabel()
    private let correctionBanner = UIStackView()
    private let correctionTitleLabel = UILabel()
    private let correctionNoteLabel = UILabel()
    private let headlineLabel = UILabel()
    private let metaLabel = UILabel()
    private let bodyTextView = UITextView()
    private let sourcesStack = UIStackView()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: Init

    init(
        slug: String,
        card: ArticleCard?,
        repository: any MagazineRepositing,
        onOpenCatalogGame: ((CatalogGameID) -> Void)? = nil
    ) {
        self.slug = slug
        self.card = card
        self.repository = repository
        self.onOpenCatalogGame = onOpenCatalogGame
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(slug:card:repository:)") }

    deinit { loadTask?.cancel() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpBackground
        title = L10n.Product22.Section.editorialCuration
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextSecondary)
        setupViews()
        applyCard()
        load()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Under pressure the body text is what matters; the decoded hero is
        // the largest thing here and is the first to go.
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    // MARK: Setup

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        heroImageView.contentMode = .scaleAspectFill
        heroImageView.clipsToBounds = true
        heroImageView.layer.cornerRadius = 12
        heroImageView.isHidden = true
        heroImageView.isAccessibilityElement = false
        heroImageView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        heroPlaceholderLabel.font = .preferredFont(forTextStyle: .footnote)
        heroPlaceholderLabel.adjustsFontForContentSizeCategory = true
        heroPlaceholderLabel.textColor = .gpTextTertiary
        heroPlaceholderLabel.numberOfLines = 0
        heroPlaceholderLabel.isHidden = true

        correctionTitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        correctionTitleLabel.adjustsFontForContentSizeCategory = true
        correctionTitleLabel.textColor = .gpOrange
        correctionTitleLabel.numberOfLines = 0

        correctionNoteLabel.font = .preferredFont(forTextStyle: .footnote)
        correctionNoteLabel.adjustsFontForContentSizeCategory = true
        correctionNoteLabel.textColor = .gpTextSecondary
        correctionNoteLabel.numberOfLines = 0

        correctionBanner.axis = .vertical
        correctionBanner.spacing = 4
        correctionBanner.isLayoutMarginsRelativeArrangement = true
        correctionBanner.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        correctionBanner.backgroundColor = .gpSurface
        correctionBanner.layer.cornerRadius = 10
        correctionBanner.addArrangedSubview(correctionTitleLabel)
        correctionBanner.addArrangedSubview(correctionNoteLabel)
        correctionBanner.isHidden = true

        headlineLabel.font = .preferredFont(forTextStyle: .title1)
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.textColor = .gpTextPrimary
        headlineLabel.numberOfLines = 0
        headlineLabel.accessibilityTraits = .header

        metaLabel.font = .preferredFont(forTextStyle: .footnote)
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.textColor = .gpTextSecondary
        metaLabel.numberOfLines = 0

        // Editing off, scrolling off, data detectors off: the text view is a
        // renderer, not an input surface, and must not turn arbitrary text in
        // the body into a tappable destination of its own.
        bodyTextView.isEditable = false
        bodyTextView.isSelectable = true
        bodyTextView.isScrollEnabled = false
        bodyTextView.dataDetectorTypes = []
        bodyTextView.backgroundColor = .clear
        bodyTextView.textContainerInset = .zero
        bodyTextView.textContainer.lineFragmentPadding = 0
        bodyTextView.adjustsFontForContentSizeCategory = true
        bodyTextView.delegate = self
        bodyTextView.linkTextAttributes = [.foregroundColor: UIColor.gpPrimary]

        sourcesStack.axis = .vertical
        sourcesStack.spacing = 10

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .gpTextSecondary
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.isHidden = true

        activityIndicator.hidesWhenStopped = true

        [heroImageView, heroPlaceholderLabel, correctionBanner, headlineLabel,
         metaLabel, bodyTextView, sourcesStack, statusLabel, activityIndicator]
            .forEach(contentStack.addArrangedSubview)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    // MARK: Card — everything typed that we already have

    private func applyCard() {
        guard let card else { return }
        headlineLabel.text = card.headline          // server content
        metaLabel.text = card.excerpt               // server content
        applyCorrectionBanner(isCorrected: card.isCorrected, changeNote: nil)

        if let hero = card.heroImage {
            // Only a rights-reviewed https asset ever reaches this point;
            // `ArticleMapper` drops anything else.
            heroImageView.isHidden = false
            heroImageView.kf.setImage(with: hero.url)
            if let attribution = hero.attribution {
                heroPlaceholderLabel.isHidden = false
                heroPlaceholderLabel.text = attribution
            }
        } else if card.heroImageWithheldReason != nil {
            // A stable placeholder, not a broken image and not a silent gap.
            heroPlaceholderLabel.isHidden = false
            heroPlaceholderLabel.text = L10n.Product22.Article.heroWithheld
        }

        applyRelatedGames(card.relatedGames)
    }

    private func applyCorrectionBanner(isCorrected: Bool, changeNote: String?) {
        guard isCorrected else {
            correctionBanner.isHidden = true
            return
        }
        correctionBanner.isHidden = false
        correctionTitleLabel.text = L10n.Product22.Article.corrected
        if let changeNote, !changeNote.isEmpty {
            correctionNoteLabel.isHidden = false
            correctionNoteLabel.text = "\(L10n.Product22.Article.changeNote): \(changeNote)"
        } else {
            correctionNoteLabel.isHidden = true
        }
        correctionBanner.accessibilityLabel = [
            correctionTitleLabel.text, correctionNoteLabel.text
        ].compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: Loading

    private func load() {
        loadTask?.cancel()
        activityIndicator.startAnimating()
        statusLabel.isHidden = true

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let article = try await repository.article(slug: slug)
                guard !Task.isCancelled else { return }
                await MainActor.run { self.render(article) }
            } catch {
                guard !Task.isCancelled else { return }
                let mapped = Product22ErrorMapper.map(error)
                guard !mapped.isCancellation else { return }
                await MainActor.run { self.renderFailure() }
            }
        }
    }

    @MainActor
    private func render(_ article: Article) {
        activityIndicator.stopAnimating()
        headlineLabel.text = article.headline
        metaLabel.text = article.excerpt
        applyCorrectionBanner(
            isCorrected: article.isCorrected,
            changeNote: article.revision.changeNote
        )

        if card?.heroImage == nil, article.heroImageWithheldReason != nil {
            heroPlaceholderLabel.isHidden = false
            heroPlaceholderLabel.text = L10n.Product22.Article.heroWithheld
        }

        if let output = try? ArticleMarkdownRenderer.renderIfSupported(article) {
            bodyTextView.attributedText = output.attributedString
        } else {
            // An unsupported body format is refused rather than rendered by
            // guesswork; the reader is told, not shown something wrong.
            bodyTextView.attributedText = nil
            statusLabel.isHidden = false
            statusLabel.text = L10n.Common.Error.unknown
        }

        sources = article.sources
        applySources(article.sources)
    }

    @MainActor
    private func renderFailure() {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = false
        statusLabel.text = L10n.Common.Error.network
    }

    // MARK: Sources

    private func applySources(_ sources: [ArticleSource]) {
        sourcesStack.arrangedSubviews.forEach {
            sourcesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        guard !sources.isEmpty else { return }

        let heading = UILabel()
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        heading.textColor = .gpTextPrimary
        heading.text = L10n.Product22.Article.sources
        heading.accessibilityTraits = .header
        sourcesStack.addArrangedSubview(heading)

        for (index, source) in sources.enumerated() {
            sourcesStack.addArrangedSubview(makeSourceView(source, index: index))
        }
    }

    private func makeSourceView(_ source: ArticleSource, index: Int) -> UIView {
        let publisher = UILabel()
        publisher.font = .preferredFont(forTextStyle: .caption1)
        publisher.adjustsFontForContentSizeCategory = true
        publisher.textColor = .gpTextTertiary
        publisher.numberOfLines = 0
        publisher.text = source.publisherKey

        let headline = UILabel()
        headline.font = .preferredFont(forTextStyle: .subheadline)
        headline.adjustsFontForContentSizeCategory = true
        headline.textColor = .gpTextPrimary
        headline.numberOfLines = 0
        headline.text = source.headline

        let excerpt = UILabel()
        excerpt.font = .preferredFont(forTextStyle: .footnote)
        excerpt.adjustsFontForContentSizeCategory = true
        excerpt.textColor = .gpTextSecondary
        excerpt.numberOfLines = 0
        excerpt.text = source.excerpt
        excerpt.isHidden = (source.excerpt ?? "").isEmpty

        let timestamps = UILabel()
        timestamps.font = .preferredFont(forTextStyle: .caption2)
        timestamps.adjustsFontForContentSizeCategory = true
        timestamps.textColor = .gpTextTertiary
        timestamps.numberOfLines = 0
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        var stamps = ["\(L10n.Product22.Article.sourceFetchedAt) \(formatter.string(from: source.fetchedAt))"]
        if let published = source.publishedAt {
            stamps.insert(formatter.string(from: published), at: 0)
        }
        timestamps.text = stamps.joined(separator: " · ")

        let stack = UIStackView(arrangedSubviews: [publisher, headline, excerpt, timestamps])
        stack.axis = .vertical
        stack.spacing = 3

        let container = UIControl()
        container.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        container.isAccessibilityElement = true
        container.accessibilityLabel = [source.publisherKey, source.headline].joined(separator: ", ")

        if source.isOpenable {
            container.tag = index
            container.addTarget(self, action: #selector(sourceTapped(_:)), for: .touchUpInside)
            container.accessibilityTraits = .link
        } else {
            // A plaintext link is shown for transparency but is not tappable,
            // and says why rather than failing silently on tap.
            container.accessibilityTraits = .staticText
            let notice = UILabel()
            notice.font = .preferredFont(forTextStyle: .caption2)
            notice.adjustsFontForContentSizeCategory = true
            notice.textColor = .gpTextTertiary
            notice.numberOfLines = 0
            notice.text = L10n.Product22.Article.sourceNotOpenable
            stack.addArrangedSubview(notice)
            container.accessibilityLabel? += ", \(L10n.Product22.Article.sourceNotOpenable)"
        }

        return container
    }

    @objc private func sourceTapped(_ sender: UIControl) {
        guard sources.indices.contains(sender.tag) else { return }
        open(sources[sender.tag].url)
    }

    // MARK: Related games

    private func applyRelatedGames(_ related: [ArticleRelatedGame]) {
        guard !related.isEmpty, onOpenCatalogGame != nil else { return }
        let heading = UILabel()
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        heading.textColor = .gpTextPrimary
        heading.text = L10n.Product22.Article.relatedGames
        heading.accessibilityTraits = .header
        contentStack.addArrangedSubview(heading)

        for game in related {
            let button = UIButton(type: .system)
            button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.contentHorizontalAlignment = .leading
            // The canonical UUID is what identifies the game. It is never
            // converted into the legacy integer id.
            button.setTitle(game.catalogGameID.wireValue, for: .normal)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addAction(
                UIAction { [weak self] _ in self?.onOpenCatalogGame?(game.catalogGameID) },
                for: .touchUpInside
            )
            contentStack.addArrangedSubview(button)
        }
    }

    // MARK: Opening a link

    /// Only https, and only in `SFSafariViewController`. A non-https URL never
    /// reaches here — `ArticleSource.isOpenable` gates it — and this second
    /// check keeps that true if a caller is ever added.
    private func open(_ url: URL) {
        guard url.scheme?.lowercased() == "https" else { return }
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = .gpPrimary
        present(safari, animated: true)
    }
}

// MARK: - UITextViewDelegate

extension ArticleReaderViewController: UITextViewDelegate {
    /// The renderer already stripped every non-https link, so this should only
    /// ever see https. It re-checks anyway and routes through
    /// `SFSafariViewController` rather than letting UIKit open the URL, which
    /// would hand a scheme like `tel:` or a custom one straight to the system.
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        guard interaction == .invokeDefaultAction else { return false }
        open(URL)
        return false
    }
}
