//
//  HistoryViewController.swift
//  Daily Adventure
//
//  Created by Vishal Bhogal on 09/04/26.
//

import UIKit
import SwiftData
import SwiftUI

// MARK: - Diffable Types
nonisolated enum HistorySection: Hashable, Sendable {
    case metrics
    case adventures
}

nonisolated enum HistoryItem: Hashable, Sendable {
    case metric(title: String, value: String, symbol: String)
    case adventure(id: UUID)
}

@MainActor
class HistoryViewController: UIViewController {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<HistorySection, HistoryItem>!
    
    private var allChallenges: [DailyChallenge] = []
    
    // MARK: - Init
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
        self.title = "HISTORY"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        configureDataSource()
        fetchData()
    }
    
    // MARK: - Setup
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self else { return nil }
            let snapshot = self.dataSource.snapshot()
            guard sectionIndex < snapshot.sectionIdentifiers.count else { return nil }
            let section = snapshot.sectionIdentifiers[sectionIndex]
            
            switch section {
            case .metrics:
                return self.createMetricsSection()
            case .adventures:
                return self.createAdventuresSection()
            }
        }
        return layout
    }
    
    private func createMetricsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 8)
        
        let secondItem = NSCollectionLayoutItem(layoutSize: itemSize)
        secondItem.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 16)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, secondItem])
        
        return NSCollectionLayoutSection(group: group)
    }
    
    private func createAdventuresSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 20, trailing: 16)
        section.interGroupSpacing = 12
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [sectionHeader]
        
        return section
    }
    
    // MARK: - Data Source
    
    private func configureDataSource() {
        let metricCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, HistoryItem> { cell, indexPath, item in
            guard case let .metric(title, value, symbol) = item else { return }
            
            var content = UIListContentConfiguration.valueCell()
            content.text = title
            content.secondaryText = value
            content.image = UIImage(systemName: symbol)
            content.imageProperties.tintColor = .secondaryLabel
            
            cell.contentConfiguration = content
            cell.layer.cornerRadius = 18
            cell.layer.cornerCurve = .continuous
            cell.backgroundColor = .secondarySystemGroupedBackground
        }
        
        let adventureCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, HistoryItem> { cell, indexPath, item in
            guard case let .adventure(id) = item,
                  let challenge = self.allChallenges.first(where: { $0.id == id }) else { return }
            
            var content = UIListContentConfiguration.subtitleCell()
            content.text = challenge.placeName
            content.secondaryText = challenge.detail
            content.image = UIImage(systemName: challenge.symbolName)
            
            cell.contentConfiguration = content
            cell.layer.cornerRadius = 24
            cell.layer.cornerCurve = .continuous
            cell.backgroundColor = .secondarySystemGroupedBackground
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { headerView, _, _ in
            var content = UIListContentConfiguration.header()
            content.text = "COMPLETED ADVENTURES"
            content.textProperties.font = .systemFont(ofSize: 13, weight: .semibold)
            content.textProperties.color = .secondaryLabel
            headerView.contentConfiguration = content
        }
        
        dataSource = UICollectionViewDiffableDataSource<HistorySection, HistoryItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .metric:
                return collectionView.dequeueConfiguredReusableCell(using: metricCellRegistration, for: indexPath, item: item)
            case .adventure:
                return collectionView.dequeueConfiguredReusableCell(using: adventureCellRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }
    
    private func fetchData() {
        let descriptor = FetchDescriptor<DailyChallenge>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        do {
            allChallenges = try modelContext.fetch(descriptor).filter { $0.completedAt != nil }
            updateSnapshot()
        } catch {
            print("Fetch failed")
        }
    }
    
    private func updateSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<HistorySection, HistoryItem>()
        snapshot.appendSections([.metrics, .adventures])
        
        let weeklyCount = calculateWeeklyCount()
        snapshot.appendItems([
            HistoryItem.metric(title: "This Week", value: "\(weeklyCount)", symbol: "calendar"),
            HistoryItem.metric(title: "Total", value: "\(allChallenges.count)", symbol: "shoeprints.fill")
        ], toSection: .metrics)
        
        snapshot.appendItems(allChallenges.map { HistoryItem.adventure(id: $0.id) }, toSection: .adventures)
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func calculateWeeklyCount() -> Int {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return allChallenges.filter { ($0.completedAt ?? .distantPast) >= start }.count
    }
}
