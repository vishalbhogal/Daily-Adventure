//
//  ProofPhotoStore.swift
//  Daily Adventure
//
//  Created by Codex on 09/04/26.
//

import Foundation
import UIKit

enum ProofPhotoStore {
    static func save(_ data: Data, for challengeID: UUID) throws -> String {
        let directory = try proofDirectory()
        let fileURL = directory.appendingPathComponent("\(challengeID.uuidString).jpg")
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    static func loadImage(at path: String?) -> UIImage? {
        guard let path else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private static func proofDirectory() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documents.appendingPathComponent("ProofShots", isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }
}
