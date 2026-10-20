import SwiftUI

/// グループのひとこと（2026-10-19 から試験。`RotashFeatureFlags.groupMessages`）。
///
/// 写真への反応を LINE で送っていたのを、アプリの中でできるようにする。
/// 担当でない日にも「やること」ができ、撮った人には「見てもらえた」が届く（DIRECTION_2026-10.md 柱 A）。
/// リアルタイムではない。開いたとき・送ったとき・引っぱったときに同期して、届いているものを出す。
struct GroupChatView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var isEditing: Bool

    private var messages: [GroupMessage] { app.group?.visibleMessages ?? [] }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                HairLine()
                list
                HairLine()
                composer
            }
        }
        .task {
            AnalyticsService.messagesOpened(unread: app.unreadMessageCount)
            app.markMessagesRead()
            await app.sync()
        }
        // 開いているあいだに届いた分も、読んだことにする。
        .onChange(of: messages.count) { _, _ in app.markMessagesRead() }
    }

    // MARK: - Blocks

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MESSAGES").rotashLabel(11, color: Palette.text, tracking: 3)
                if let group = app.group {
                    Text(group.name.uppercased()).rotashLabel(9, color: Palette.faint, tracking: 1.6)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Text("とじる")
                    .rotashLabel(11, color: Palette.text, tracking: 1.6)
                    .frame(minWidth: 64, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if messages.isEmpty {
                        Text("まだメッセージはありません。\n写真の感想や「ありがとう」を送ってみましょう。")
                            .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                            .lineSpacing(5)
                            .padding(.top, 24)
                    }
                    ForEach(messages) { message in
                        row(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await Task { await app.sync(showingError: true) }.value }
            .onAppear { scrollToBottom(proxy, animated: false) }
            .onChange(of: messages.last?.id) { _, _ in scrollToBottom(proxy, animated: true) }
        }
    }

    private func row(_ message: GroupMessage) -> some View {
        let isMine = message.senderID == app.group?.myMemberID
        return VStack(alignment: isMine ? HorizontalAlignment.trailing : HorizontalAlignment.leading, spacing: 5) {
            HStack(spacing: 8) {
                if !isMine {
                    Text(senderName(message).uppercased()).rotashLabel(9, color: Palette.text, tracking: 1.2)
                }
                Text(timeLabel(message.sentAt)).rotashLabel(8, color: Palette.faint, tracking: 0.8)
            }
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.text)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isMine ? Palette.surface : Palette.surfaceDeep)
                .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: isMine ? Alignment.trailing : Alignment.leading)
        .padding(isMine ? Edge.Set.leading : Edge.Set.trailing, 40)
        .contextMenu {
            // 報告・見えなくする（App Store ガイドライン 1.2）。自分のひとことには出さない。
            if !isMine {
                Button(role: .destructive) { app.report(message) } label: {
                    Label("報告する", systemImage: "exclamationmark.bubble")
                }
                Button { app.setMemberHidden(message.senderID, hidden: true) } label: {
                    Label("この人を見えなくする", systemImage: "eye.slash")
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("メッセージ", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundStyle(Palette.text)
                .focused($isEditing)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Palette.surfaceDeep)
                .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
                .onChange(of: draft) { _, value in
                    // 長文の掲示板にはしない。上限を超えた分は入らない。
                    if value.count > GroupMessage.textLimit { draft = String(value.prefix(GroupMessage.textLimit)) }
                }
            Button {
                app.sendMessage(draft)
                draft = ""
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(canSend ? Palette.live : Palette.faint)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel(Text("送信"))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: -

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func senderName(_ message: GroupMessage) -> String {
        app.group?.member(withID: message.senderID)?.name ?? "—"
    }

    /// 今日なら時刻だけ、それより前なら日付と時刻。
    private func timeLabel(_ date: Date) -> String {
        let time = RotashDateFormat.time.string(from: date)
        if Calendar.rotash.isDateInToday(date) { return time }
        return "\(RotashDateFormat.monthDay.string(from: date)) \(time)"
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let last = messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last, anchor: .bottom) }
        } else {
            proxy.scrollTo(last, anchor: .bottom)
        }
    }
}
