//
//  Untitled.swift
//  GamePedia
//
//  Created by Hwangseokbeom on 3/23/26.
//

import UIKit

final class CustomTabBarView: UIView {

    var onTabSelected: ((Int) -> Void)?

    private let blurContainerView = UIView()
    private let selectedBackgroundView = UIView()
    private let stackView = UIStackView()

    private var tabButtons: [UIButton] = []
    private var selectedIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupTabs()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blurContainerView.frame = bounds
        blurContainerView.layer.cornerRadius = bounds.height / 2
        moveSelectedBackground(animated: false)
    }

    func updateSelectedIndex(_ index: Int) {
        selectedIndex = index
        updateButtonStates()
        moveSelectedBackground(animated: true)
    }

    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = false

        blurContainerView.backgroundColor = .gpSurface
        blurContainerView.layer.cornerRadius = 36
        blurContainerView.layer.shadowColor = UIColor.black.cgColor
        blurContainerView.layer.shadowOffset = CGSize(width: 0, height: 8)
        blurContainerView.layer.shadowRadius = 20
        blurContainerView.layer.shadowOpacity = 0.35
        blurContainerView.clipsToBounds = false
        addSubview(blurContainerView)

        selectedBackgroundView.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.18)
        selectedBackgroundView.layer.cornerRadius = 28
        blurContainerView.addSubview(selectedBackgroundView)

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        blurContainerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: blurContainerView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: blurContainerView.trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: blurContainerView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: blurContainerView.bottomAnchor, constant: -8)
        ])
    }

    private func setupTabs() {
        let items: [(title: String, image: String, selectedImage: String)] = [
            ("홈", "house", "house.fill"),
            ("검색", "magnifyingglass", "magnifyingglass"),
            ("라이브러리", "books.vertical", "books.vertical.fill"),
            ("프로필", "person", "person.fill")
        ]

        items.enumerated().forEach { index, item in
            let button = UIButton(type: .system)
            button.tag = index
            button.tintColor = .gpTextTertiary
            button.setTitle(item.title, for: .normal)
            button.setTitle(item.title, for: .selected)
            button.setImage(UIImage(systemName: item.image), for: .normal)
            button.setImage(UIImage(systemName: item.selectedImage), for: .selected)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            button.setTitleColor(.gpTextTertiary, for: .normal)
            button.setTitleColor(.gpPrimary, for: .selected)
            button.contentHorizontalAlignment = .center
            button.adjustsImageWhenHighlighted = false
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)

            button.configuration = nil
            button.semanticContentAttribute = .forceTopToBottom
            button.imageView?.contentMode = .scaleAspectFit
            button.titleLabel?.textAlignment = .center

            let containerView = UIView()
            containerView.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                button.topAnchor.constraint(equalTo: containerView.topAnchor),
                button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])

            stackView.addArrangedSubview(containerView)
            tabButtons.append(button)
        }

        updateButtonStates()
    }

    private func updateButtonStates() {
        tabButtons.enumerated().forEach { index, button in
            let isSelected = index == selectedIndex
            button.isSelected = isSelected
            button.tintColor = isSelected ? .gpPrimary : .gpTextTertiary
        }
    }

    private func moveSelectedBackground(animated: Bool) {
        guard !tabButtons.isEmpty else { return }

        let itemWidth = (blurContainerView.bounds.width - 16) / CGFloat(tabButtons.count)
        let backgroundWidth = itemWidth
        let backgroundHeight = blurContainerView.bounds.height - 16

        let targetFrame = CGRect(
            x: 8 + (CGFloat(selectedIndex) * itemWidth),
            y: 8,
            width: backgroundWidth,
            height: backgroundHeight
        )

        if animated {
            UIView.animate(withDuration: 0.25) {
                self.selectedBackgroundView.frame = targetFrame
            }
        } else {
            selectedBackgroundView.frame = targetFrame
        }
    }

    @objc
    private func tabButtonTapped(_ sender: UIButton) {
        onTabSelected?(sender.tag)
    }
}
