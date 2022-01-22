### Models

- Room

```swift
import Foundation

struct Room: Codable {
    var id: String?
    let name: String
    let description: String
}
```

- Message

```swift
import Foundation

struct Message: Codable {

    var id: String?
    var text: String = ""
    var username: String = ""
    var roomId: String = ""
    var messageDate: Date = Date()

    init(vs: MessageViewState) {
        text = vs.message
        username = vs.username
        roomId = vs.roomId
    }

}
```

### ViewModels

- AddRoomViewModel

```swift
import Foundation
import Firebase
import FirebaseFirestoreSwift

class AddRoomViewModel: ObservableObject {

    var name: String = ""
    var description: String = ""
    let db = Firestore.firestore()

    func createRoom(completion: @escaping () -> Void) {

        let room = Room(name: name, description: description)

        do {

        _ = try db.collection("rooms")
            .addDocument(from: room, encoder: Firestore.Encoder()) { (error) in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    completion()
                }
            }
        } catch let error {
            print(error.localizedDescription)
        }

    }

}
```

- RoomListViewModel

```swift
import Foundation
import Firebase
import FirebaseFirestoreSwift

struct RoomViewModel {

    let room: Room

    var name: String {
        room.name
    }

    var description: String {
        room.description
    }

    var roomId: String {
        room.id ?? ""
    }

}

class RoomListViewModel: ObservableObject {

    @Published var rooms: [RoomViewModel] = []
    let db = Firestore.firestore()

    func getAllRooms() {
        db.collection("rooms")
            .getDocuments { snapshot, error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    if let snapshot = snapshot {
                        let rooms: [RoomViewModel] = snapshot.documents.compactMap { doc in
                            guard var room = try? doc.data(as: Room.self) else {
                                return nil
                            }
                            room.id = doc.documentID
                            return RoomViewModel(room: room)
                        }
                        DispatchQueue.main.async {
                            self.rooms = rooms
                        }
                    }
                }
            }
    }

}
```

- MessageListViewModel

```swift
import Foundation
import Firebase
import FirebaseFirestoreSwift

struct MessageViewState {
    let message: String
    let roomId: String
    let username: String
}

struct MessageViewModel {

    let message: Message

    var messageText: String {
        message.text
    }

    var username: String {
        message.username
    }

    var messageId: String {
        message.id ?? ""
    }

}

class MessageListViewModel: ObservableObject {

    let db = Firestore.firestore()
    @Published var messages: [MessageViewModel] = []

    func registerUpdatesForRoom(room: RoomViewModel) {

        db.collection("rooms")
            .document(room.roomId)
            .collection("messages")
            .order(by: "messageDate", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    if let snapshot = snapshot {
                        let messages: [MessageViewModel] = snapshot.documents.compactMap { doc in
                            guard var message: Message = try? doc.data(as: Message.self) else { return nil }
                            message.id = doc.documentID
                            return MessageViewModel(message: message)
                        }
                        DispatchQueue.main.async {
                            self.messages = messages
                        }
                    }
                }
            }
    }

    func sendMessage(msg: MessageViewState, completion: @escaping() -> Void) {

        let message = Message(vs: msg)

        do {
            _ = try db.collection("rooms")
                .document(message.roomId)
                .collection("messages")
                .addDocument(from: message, encoder: Firestore.Encoder()) { error in
                    if let error = error {
                        print(error.localizedDescription)
                    } else {
                        completion()
                    }
                }
        } catch let error {
            print(error.localizedDescription)
        }

    }

}
```

### Views

- MessageListView

```swift
import SwiftUI
import Combine

struct MessageListView: View {

    let room: RoomViewModel

    @StateObject private var messageListVM: MessageListViewModel = MessageListViewModel()

    @State private var message: String = ""
    @State private var cancellables: AnyCancellable?
    @AppStorage("username") private var username = ""

    private func sendMessage() {

        let messageVS = MessageViewState(message: message, roomId: room.roomId, username: username)

        messageListVM.sendMessage(msg: messageVS) {
            message = ""
        }

    }

    var body: some View {

        VStack {
            ScrollView {
                ScrollViewReader { scrollView in
                    VStack {

                        ForEach(messageListVM.messages, id: \.messageId) { message in
                            HStack {
                                if message.username == username {
                                    Spacer()
                                    MessageView(messageText: message.messageText, username: message.username, style: .primary)
                                } else {
                                    MessageView(messageText: message.messageText, username: message.username, style: .secondary)
                                    Spacer()
                                }
                            }
                            .padding()
                            .id(message.messageId) // scorll
                        }

                    }
                    .onAppear {
                        // Publisher
                        cancellables = messageListVM.$messages.sink { messages in
                            if messages.count > 0 {
                                DispatchQueue.main.async {
                                    withAnimation {
                                        scrollView.scrollTo(messages[messages.endIndex - 1].messageId, anchor: .bottom)

                                    }
                                }
                            }
                        }
                    }
                }
            }

            Spacer()

            HStack {
                TextField("Write message here", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                   sendMessage()
                }, label: {
                    Image(systemName: "paperplane.fill")
                })
            }.padding()
            .background(Color(#colorLiteral(red: 0.9483042359, green: 0.9484629035, blue: 0.9482833743, alpha: 1)))
        }
        .navigationTitle(room.name)
        .onAppear(perform: {
            messageListVM.registerUpdatesForRoom(room: room)
        })
    }
}

struct MessageListView_Previews: PreviewProvider {
    static var previews: some View {
        MessageListView(room: RoomViewModel(room: Room(name: "Sports", description: "This is sports room")))
            .embedInNavigationView()
    }
}
```
