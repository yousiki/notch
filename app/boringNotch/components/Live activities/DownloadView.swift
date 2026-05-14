//
//  DownloadView.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 17/08/24.
//

import Foundation
import SwiftUI

enum Browser {
    case safari
    case chrome
}

struct DownloadFile {
    var name: String
    var size: Int
    var formattedSize: String
    var browser: Browser
}

final class DownloadWatcher: ObservableObject {
    @Published var downloadFiles: [DownloadFile] = []
}

struct DownloadArea: View {
    @EnvironmentObject var watcher: DownloadWatcher

    var body: some View {
        if let downloadFile = watcher.downloadFiles.first {
            HStack(alignment: .center) {
                HStack {
                    if downloadFile.browser == .safari {
                        AppIcon(for: "com.apple.safari")
                    } else {
                        Image(.chrome).resizable().scaledToFit().frame(width: 30, height: 30)
                    }
                    VStack(alignment: .leading) {
                        Text("Download")
                        Text("In progress").font(.system(.footnote)).foregroundStyle(.gray)
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    VStack(alignment: .trailing) {
                        Text(downloadFile.formattedSize)
                        Text(downloadFile.name).font(.caption2).foregroundStyle(.gray)
                    }
                }
            }
        }
    }
}
