// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct StartPage: View {
    @Bindable var browser: BrowserModel
    var focusAddress: () -> Void
    var showPrivacy: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 16) {
                            HarborMark().frame(width: 60, height: 60)
                            Text("Harbor").font(.custom("InterVariable", size: 34, relativeTo: .largeTitle).bold()).foregroundStyle(.white)
                        }
                        Button(action: showPrivacy) {
                            Label(browser.protectionStatus, systemImage: "shield.lefthalf.filled")
                                .font(.body).fixedSize(horizontal: false, vertical: true)
                                .padding(16).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.buttonStyle(.plain).foregroundStyle(.primary)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    }.padding(24).padding(.bottom, 16).frame(maxWidth: .infinity, alignment: .leading).background(Color.harborNavy)
                } else {
                ZStack(alignment: .top) {
                    HorizonArtwork()
                    VStack(spacing: 4) {
                        HarborMark().frame(width: 94, height: 94)
                        Text("Harbor").font(.custom("InterVariable", size: 34, relativeTo: .largeTitle).bold()).foregroundStyle(.white)
                        Text("An open place to return to.").font(.subheadline).foregroundStyle(.white)
                        Spacer(minLength: 70)
                        Button(action: showPrivacy) {
                            Label(browser.protectionStatus, systemImage: "shield.lefthalf.filled")
                                .font(.subheadline.weight(.medium)).padding(.horizontal, 18).frame(minHeight: 44)
                        }.buttonStyle(.plain).foregroundStyle(.primary).harborGlass()
                    }.padding(.top, 16).padding(.bottom, 26)
                }.frame(height: 350)
                }
                VStack(alignment: .leading, spacing: 26) {
                    if let recent = browser.archive.history.first {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Continue browsing").font(.title3.bold())
                            Button { browser.navigate(recent.url) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "clock.arrow.circlepath").font(.title2).foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(recent.title).font(.headline).lineLimit(2)
                                        Text(recent.url.host ?? recent.url.absoluteString).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Where to next?").font(.title2.bold())
                            Text("Search, visit a website, or pick up where you left off. Your tabs will be here when you return.")
                                .font(.body).foregroundStyle(Color.primary.opacity(0.72))
                            Button("Search or enter address", systemImage: "magnifyingglass", action: focusAddress)
                                .padding(.top, 4).frame(minHeight: 44)
                        }
                    }
                    if !browser.archive.bookmarks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Favorites").font(.title3.bold())
                            ForEach(browser.archive.bookmarks.prefix(6)) { bookmark in
                                Button { browser.navigate(bookmark.url) } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "bookmark.fill").foregroundStyle(.tint).frame(width: 28)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(bookmark.title).lineLimit(1)
                                            Text(bookmark.url.host ?? "").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                    }.frame(minHeight: 52)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if browser.archive.history.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recently visited").font(.title3.bold())
                            ForEach(Array(browser.archive.history.dropFirst().prefix(4))) { entry in
                                Button { browser.navigate(entry.url) } label: {
                                    Label(entry.title, systemImage: "globe").lineLimit(1).frame(minHeight: 44)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .systemGroupedBackground), in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
                    .padding(.top, -16)
            }
        }
        .scrollClipDisabled()
        .background {
            VStack(spacing: 0) {
                Color.harborNavy.frame(height: 350)
                Color(uiColor: .systemGroupedBackground)
            }.ignoresSafeArea(.container, edges: .vertical)
        }
        .accessibilityIdentifier("startPage")
    }
}
