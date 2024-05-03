import Foundation
import SwiftUI
import SocketIO
//import AgoraRtcKit
import AVFoundation


class JSONUtility {

    class func getJson(objects: [Any]?) -> Any? {
        if (objects == nil){
            return nil
        }
        for objectsString in objects! {
            do {
                if let objectData = (objectsString as? String)?.data(using: .utf8){
                    return try JSONSerialization.jsonObject(with: objectData, options: .mutableContainers )
                }
            }
            catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }

    class func jsonString(obj: Any, prettyPrint: Bool) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []) else{
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
}



class SocketObject: ObservableObject {
    static var shared = SocketObject()
    let ipAddress = "http://172.18.23.27:9090"
    let service = Service()
    var manager: SocketManager!
    var socket: SocketIOClient!
    var status: String!

    init() {
        self.manager = SocketManager(socketURL: URL(string: ipAddress)!, config: [.log(false), .compress])
        self.socket = self.manager.defaultSocket

        socket.on(clientEvent: .connect) { (data, ack) in
            print("Socket connected")
        }
        socket.on(clientEvent: .disconnect) { (data, ack) in
            print("Socket disconnected")
        }
        socket.onAny { (event) in
            let responseObj = JSONUtility.getJson(objects: event.items!)
            print("----------- %@\n\n", event.event, event.items as Any)
            print("----------- %@\n items %@", event.event, responseObj as Any)
        }
        socket.on("UpdateSocket") { (object, ack) in
            print("Socket response UpdateSocket : %@", object)

            if (object.count > 0) {
                if let responseObj = object[0] as? NSDictionary {
                    if responseObj.value(forKey: self.status) as? String ?? "" == "1" {
                        print("success status")
                    } else {
                        print("fail status")
                    }
                }
            }
        }
        socket.connect(timeoutAfter: 0) {
            print("--------------%d", self.socket.status)
        }
        socket.connect()
    }

    func emit(event: String, with items: NSArray) {
        switch self.socket.status {
        case .connected:
            self.socket.emit(event, items)
        case .connecting:
            print("\n\n ---------- Connecting ... --------------/n/n", event)
            self.socket.once(clientEvent: .connect) { (object, ack) in
                self.socket.emit(event, items)
                print("\n\n---------ConnectOnce-----\n\n", event)
            }
        case .disconnected:
            print("\n\n ---------- Disconnected --------------/n/n", event)
        default:
            break
        }
    }

    func joinConversation(conversationId: String) {
        switch self.socket.status {
        case .connected:
            socket.emit("join_conversation", conversationId)
        case .connecting:
            print("Socket is still connecting...")
            self.socket.once(clientEvent: .connect) { [weak self] _, _ in
                guard let self = self else { return }
                self.socket.emit("join_conversation", conversationId)
            }
        case .disconnected:
            print("Socket is disconnected.")
        default:
            break
        }
    }

    func sendMessage(conversationId: String, message: String, sender: String, type: String) {
        let messageData: [String: Any] = [
            "sender": sender,
            "conversation": conversationId,
            "content": message,
            "type": type
        ]
        socket.emit("new_message_\(conversationId)", messageData)
    }

    func listenForMessages(conversationId: String, completion: @escaping ([MessagesStructure]) -> Void) {
        // Listen for new messages
        socket.on("new_message_\(conversationId)") { [weak self] (data, ack) in
            guard let self = self else { return }
            
            print("New message received:", data)
            
            // Fetch messages using the Service
            self.service.fetchMessages(conversationId: conversationId) { json, error in
                if let error = error {
                    print("Error fetching messages: \(error)")
                    return
                }
                
                if let json = json {
                    if let messagesData = json["messages"] as? [[String: Any]] {
                        let messages = messagesData.compactMap { messageData in
                            MessagesStructure(
                                id: messageData["_id"] as? String ?? "",
                                sender: messageData["sender"] as? String ?? "",
                                content: messageData["content"] as? String ?? "",
                                timestamp: messageData["timestamp"] as? String ?? "",
                                type: messageData["type"] as? String ?? "",
                                emoji: (messageData["emojis"] as? [String])?.first ?? ""
                            )
                        }
                        DispatchQueue.main.async {
                            completion(messages)
                        }
                    }
                }
            }
        }
        
        // Listen for emoji added event
        socket.on("emoji_added") { [weak self] (data, ack) in
            guard let self = self else { return }
            
            // Fetch updated messages when emoji is added
            self.service.fetchMessages(conversationId: conversationId) { json, error in
                if let error = error {
                    print("Error fetching messages: \(error)")
                    return
                }
                
                if let json = json {
                    if let messagesData = json["messages"] as? [[String: Any]] {
                        let messages = messagesData.compactMap { messageData in
                            MessagesStructure(
                                id: messageData["_id"] as? String ?? "",
                                sender: messageData["sender"] as? String ?? "",
                                content: messageData["content"] as? String ?? "",
                                timestamp: messageData["timestamp"] as? String ?? "",
                                type: messageData["type"] as? String ?? "",
                                emoji: (messageData["emojis"] as? [String])?.first ?? ""
                            )
                        }
                        DispatchQueue.main.async {
                            completion(messages)
                        }
                    }
                }
            }
        }
    }


}





// Data structure
struct MessagesStructure: Identifiable {
    var id : String
    var sender: String
    var content: String
    var timestamp: String
    var type: String
    var emoji: String? // Added emoji property
}

// View for outgoing message
// View for outgoing message
// View for outgoing message
struct OutgoingDoubleLineMessage: View {
    let message: MessagesStructure
    let outgoingBubble = Color(#colorLiteral(red: 0.03921568627, green: 0.5176470588, blue: 1, alpha: 1))
    let senderName = "Arafet"
    let service = Service()
    
    var body: some View {
        HStack {
            if message.type == "attachment" {
                // Display the image fetched from the attachment URL
                AsyncImage(url: URL(string: message.content)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 300, height: 200) // Adjust size as needed
                            .clipped()
                    case .failure:
                        // Placeholder or error handling image
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 300, height: 200) // Adjust size as needed
                            .clipped()
                    case .empty:
                        // Placeholder or loading indicator
                        ProgressView()
                    @unknown default:
                        // Placeholder or error handling image
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 300, height: 200) // Adjust size as needed
                            .clipped()
                    }
                }
                .frame(width: 300, height: 200) // Adjust size as needed
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // Display text message
                VStack(alignment: .trailing) {
                    Text(message.content)
                        .font(.body)
                        .padding(8)
                        .foregroundColor(.white)
                        .background(RoundedRectangle(cornerRadius: 16).fill(outgoingBubble))
                    HStack {
                        Spacer()
                        Text(message.emoji ?? "") // Display timestamp
                            .foregroundColor(.gray)
                            .padding(.trailing, 8) // Add some padding between the timestamp and the edge of the bubble
                        Text(message.timestamp )
                            .foregroundColor(.gray)
                            .font(.caption)

                      
                    }
                }
            }
            Image("outgoingTail")
                .resizable()
                .frame(width: 10, height: 10)
                .padding(.trailing, -5)
            if message.sender != service.currentUser {
                Image(message.sender)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            }
            if message.sender == service.currentUser {
                Image(service.currentUser)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            }
        }
    }
}

struct IncomingDoubleLineMessage: View {
    let message: MessagesStructure
    let incomingBubble = Color.gray
    let service = Service()
    
    var body: some View {
        HStack {
            if message.sender != service.currentUser {
                Image(message.sender)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            }
            VStack(alignment: .leading) {
                if message.type == "attachment" {
                    // Display the image fetched from the attachment URL
                    AsyncImage(url: URL(string: message.content)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 300, height: 200) // Adjust size as needed
                                .clipped()
                        case .failure:
                            // Placeholder or error handling image
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 300, height: 200) // Adjust size as needed
                                .clipped()
                        case .empty:
                            // Placeholder or loading indicator
                            ProgressView()
                        @unknown default:
                            // Placeholder or error handling image
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 300, height: 200) // Adjust size as needed
                                .clipped()
                        }
                    }
                    .frame(width: 300, height: 200) // Adjust size as needed
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    // Display text message
                    Text(message.content)
                        .font(.body)
                        .padding(8)
                        .foregroundColor(.white)
                        .background(RoundedRectangle(cornerRadius: 16).fill(incomingBubble))
                    
                    HStack {
                        Text(message.timestamp) // Display timestamp
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.trailing, 8) // Add some padding between the timestamp and the edge of the bubble
                        Text(message.emoji ?? "" )
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            Image("incomingTail")
                .resizable()
                .frame(width: 10, height: 10)
                .padding(.leading, -5)
            if message.sender == service.currentUser {
                Image(service.currentUser)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            }
        }
    }
}



struct MessengerView: View {
    let service = Service()
    let senderName: String
    let conversationId: String
    @State private var messages: [MessagesStructure] = []
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var socketObject = SocketObject.shared

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .padding(.leading, -10)
                }.onDisappear {
                    // Disconnect from socket when leaving the view
                    socketObject.socket.disconnect()
                }
                Image(senderName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
                VStack(alignment: .leading) {
                    Text(senderName)
                        .font(.title)
                        .foregroundColor(.black)
                        .padding(.leading, 2)
                }
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Online")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
     
                    Image(systemName: "video.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                
                Image(systemName: "phone.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .padding()
            
            GeometryReader { geometry in
                ScrollViewReader { scrollView in
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(messages.indices, id: \.self) { index in
                                HStack {
                                    if messages[index].sender == service.currentUser {
                                        OutgoingDoubleLineMessage(message: messages[index])
                                    } else {
                                        IncomingDoubleLineMessage(message: messages[index])
                                    }
                                    if messages[index].sender != service.currentUser {
                                        EmojiButton(conversationId: conversationId, messageId: messages[index].id, service: service)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .id(index)
                            }
                        }
                        .onChange(of: messages.count) { _ in
                            if messages.count > 0 {
                                withAnimation {
                                    scrollView.scrollTo(messages.count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            
            ComposeArea(conversationId: conversationId, currentUserId: service.currentUser)
        }
        .padding(.bottom)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            onAppear()
        }
        .onDisappear{
            onDisappear()
        }
    }
    
    
    func onAppear() {
        socketObject.socket.connect()
        
        service.fetchMessages(conversationId: conversationId) { json, error in
            if let error = error {
                print("Error fetching messages: \(error)")
                return
            }

            if let json = json {
                if let messagesData = json["messages"] as? [[String: Any]] {
                    self.messages = messagesData.compactMap { messageData in
                        MessagesStructure(
                            id:messageData["_id"] as? String ?? "",
                            sender: messageData["sender"] as? String ?? "",
                            content: messageData["content"] as? String ?? "",
                            timestamp: messageData["timestamp"] as? String ?? "",
                            type: messageData["type"] as? String ?? "",
                            emoji: (messageData["emojis"] as? [String])?.first ?? ""
                        )
                    }
                }
            }
        }
        listenForMessages()
        socketObject.joinConversation(conversationId: conversationId)
    }
    
    func onDisappear() {
        socketObject.socket.off("new_message_\(conversationId)")
    }
    
    func listenForMessages() {
        socketObject.listenForMessages(conversationId: conversationId) { newMessages in
            self.messages = newMessages
        }
    }
}




// Emoji button view
// Emoji button view
struct EmojiButton: View {
    @State private var isEmojiPickerPresented = false
    @State private var selectedEmoji: String = "" // Add a state property to hold the selected emoji
    
    let conversationId: String
    let messageId: String
    let service: Service // Add a property for the Service
    
    var body: some View {
        Button(action: {
            isEmojiPickerPresented.toggle()
        }) {
            Image(systemName: "smiley")
                .font(.title)
        }
        .overlay(
            EmojiPickerDialog(isPresented: $isEmojiPickerPresented) { emoji in
                self.selectedEmoji = emoji // Set the selected emoji
            }
            .frame(width: 200, height: 30) // Adjust size as needed
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 5)
            .opacity(isEmojiPickerPresented ? 1 : 0) // Show only when isEmojiPickerPresented is true
        )
        .onChange(of: selectedEmoji) { emoji in
            if !emoji.isEmpty {
                service.addReaction(messageId: self.messageId, reaction: emoji) // Add reaction using the service
                
                
            }
        }
    }
}

  



struct EmojiPickerDialog: View {
    @Binding var isPresented: Bool
    let onSelectEmoji: (String) -> Void // Closure to handle emoji selection
    
    var emojis = ["😊", "😂", "😍", "👍", "👏", "❤️", "🔥", "🎉", "🤔"]
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { // Decreased spacing
                    ForEach(emojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 20)) // Decreased font size
                            .onTapGesture {
                                self.onSelectEmoji(emoji) // Call the closure to handle emoji selection
                                self.isPresented.toggle() // Close the emoji picker
                            }
                    }
                    .padding(5) // Decreased padding
                }
            }
            .padding(10) // Increased padding around the ScrollView
            .frame(height: 40) // Adjusted height of ScrollView
        }
    }
}



struct ComposeArea: View {
    @State private var write: String = ""
    @State private var isSendingMessage = false // Track whether a message is being sent
    @StateObject private var socketObject = SocketObject.shared
    @State private var selectedFile: URL? = nil // Track the selected file
    @State private var isFilePickerPresented = false // Track whether the file picker is presented
    
    let conversationId: String // Conversation ID
    let currentUserId: String // Current user ID

    var body: some View {
        HStack {
            Button(action: {
                isFilePickerPresented = true // Show the file picker when the button is pressed
            }) {
                Image(systemName: "camera.fill")
                    .font(.title)
            }
            .fileImporter(isPresented: $isFilePickerPresented, allowedContentTypes: [.image]) { result in
                do {
                    let selectedURL = try result.get()
                    self.selectedFile = selectedURL
                    // Call the sendAttachment function when a file is selected
                    sendAttachment()
                } catch {
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }

            
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .stroke()
                HStack{
                    TextField("Write a message", text: $write)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "waveform.circle.fill")
                        .font(.title)
                }
                .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 3))
            }
            .frame(width: 249, height: 33)
            
            Button(action: {
                sendMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.title)
            }
            .disabled(isSendingMessage) // Disable button while a message is being sent
        }
        .foregroundColor(Color(.systemGray))
        .padding()
    }
    
    private func sendMessage() {
        guard !write.isEmpty && !isSendingMessage else { return } // Ensure message is not empty and not already sending
        
        // Update state to indicate that a message is being sent
        isSendingMessage = true
        
        // Send the message
        socketObject.sendMessage(conversationId: conversationId, message: write, sender: currentUserId, type: "text")
        
        // Reset state after message is sent
        isSendingMessage = false
        write = "" // Clear the text field after sending the message
    }
    private func sendAttachment() {
        guard let selectedFile = selectedFile else {
            // Handle case when no file is selected
            return
        }

        // Update state to indicate that an attachment is being sent
        isSendingMessage = true

        // Call the service to upload the attachment
        let service = Service() // Create an instance of the Service class
        service.sendAttachment(conversationId: conversationId, fileURL: selectedFile) { (attachmentURL: String?, error: Error?) in
            if let error = error {
                // Handle the error
                print("Error sending attachment: \(error.localizedDescription)")
                // Reset state
                DispatchQueue.main.async {
                    self.isSendingMessage = false
                }
                return
            }

            if let attachmentURL = attachmentURL {
                // Send the message with the attachment URL
                self.socketObject.sendMessage(conversationId: self.conversationId, message: attachmentURL, sender: self.currentUserId, type: "attachment")

                // Reset state
                DispatchQueue.main.async {
                    self.isSendingMessage = false
                    self.selectedFile = nil // Clear the selected file
                }
            }
        }
    }

}









public struct User: Identifiable {
    public let id = UUID()
    public let name: String
    public let status: String
    public let image: String
    
    public init(name: String, status: String, image: String) {
        self.name = name
        self.status = status
        self.image = image
    }
}


struct Conversation: Identifiable {
    let id : String
    let participantName: String
    let lastMessage: String
    let timestamp: Date
}

public struct ChatsView: View {
    @State private var searchText = ""
    @State private var senderN = ""
    @State private var conversations: [Conversation] = []
    @State private var conversationToDelete: Conversation? = nil
    @State private var showingDeleteAlert = false
    @State private var destinationView: AnyView? = nil
    @State private var navigateToMessengerView: Bool? = false
    @State private var selectedConversationId: String? = nil // Define selectedConversationId here

    let service = Service() // Create an instance of the Service class
    var users: [User] // Accept users as parameter
    let currentUser: String
    var apiKey: String
    
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { $0.participantName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    // Initializer
    public init(users: [User], currentUser: String, apiKey: String) {
        self.users = users
        self.currentUser = currentUser
        self.apiKey = apiKey
    }
    
    public var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(users) { user in
                            UserView(user: user)
                                .padding(.horizontal, 10)
                                .onTapGesture {
                                    // Log when the user is pressed
                                    print("User \(user.name) pressed")

                                    // Call createOrGetConversation to create or retrieve conversation ID
                                    service.createOrGetConversation(clickedUserId: user.name) { conversationId, error in
                                        if let error = error {
                                            print("Error creating/getting conversation: \(error)")
                                            return
                                        }
                                        if let conversationId = conversationId {
                                            // Log the obtained conversation ID
                                            print("Obtained conversation ID for \(user.name): \(conversationId)")
                                            
                                            // Now, trigger navigation to MessengerView with the obtained conversation ID
                                            DispatchQueue.main.async {
                                                self.selectedConversationId = conversationId
                                                self.navigateToMessengerView = true
                                                self.senderN = user.name
                                            }
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.vertical)
                    .background(
                        NavigationLink(
                            destination: MessengerView(senderName: senderN ?? "", conversationId: selectedConversationId ?? ""),
                            tag: true,
                            selection: $navigateToMessengerView
                        ) {
                            EmptyView()
                        }
                            .navigationBarBackButtonHidden(true) // Hide the navigation back button

                    )
                }
                
                Divider()
                
                List {
                    ForEach(filteredConversations) { conversation in
                        NavigationLink(destination: MessengerView(senderName: conversation.participantName, conversationId:conversation.id)) {
                            ConversationRow(conversation: conversation)
                        }
                        .swipeActions {
                            Button(action: {
                                self.setConversationToDelete(conversation)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("CrossChat")
            .navigationBarBackButtonHidden(true)
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Conversation"),
                    message: Text("Are you sure you want to delete this conversation?"),
                    primaryButton: .cancel(),
                    secondaryButton: .destructive(Text("Delete")) {
                        if let conversation = conversationToDelete {
                            self.deleteConversation(conversation)
                            
                        }
                    }
                )
            }
            .onAppear {
                // Fetch conversations when the view appears
                service.fetchConversations(currentUser: service.currentUser) { json, error in
                    if let error = error {
                        print("Error fetching conversations: \(error)")
                        return
                    }

                    if let conversationsData = json {
                        self.conversations = conversationsData.compactMap { conversationData in
                            let participants = conversationData["participants"] as? [String] ?? ["", ""]
                            let participantName = participants.first(where: { $0 != service.currentUser }) ?? ""
                            let convId = conversationData["_id"] as? String ?? "" // Get the conversation ID

                            print(participants)
                            print(participantName)

                            return Conversation(
                                id:convId ,
                                participantName: participantName,
                                lastMessage: (conversationData["messages"] as? [[String: Any]])?.last?["content"] as? String ?? "",
                                timestamp: Date() // You can parse the timestamp here
                            )
                        }
                    }

                }
            }
        }
    }

    
    private func setConversationToDelete(_ conversation: Conversation) {
        self.conversationToDelete = conversation
        self.showingDeleteAlert = true
    }
    
    private func deleteConversation(_ conversation: Conversation) {
        service.deleteConversation(conversationId: conversation.id) { error in
            if let error = error {
                print("Error deleting conversation: \(error)")
                // Handle error if needed
            } else {
                // Remove the conversation from the list if deletion is successful
                if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                    conversations.remove(at: index)
                }
            }
        }
    }

}


struct UserView: View {
    let user: User

    var body: some View {
        VStack {
            Image(user.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 3)
            Text(user.name)
        }
    }
}


struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack {
            Image(conversation.participantName) // Use a default image or placeholder if the user's image is not available
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 3)
                .padding(.trailing, 10) // Add some spacing between the image and text
            
            VStack(alignment: .leading) {
                Text(conversation.participantName)
                    .font(.headline)
                Text(conversation.lastMessage)
                    .foregroundColor(.gray)
                Text("\(conversation.timestamp)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 5)
            
            Spacer() // Add spacer to push the content to the leading edge
        }
        .padding(.horizontal) // Add horizontal padding to the whole row
    }
}


struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            TextField("Search", text: $text)
                .padding(7)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 10)
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray2))
                        .padding(.trailing, 10)
                }
            }
        }
    }
}



struct ConversationDetailView: View {
    let user: User

    var body: some View {
        Text("Conversation with \(user.name)")
            .navigationTitle(user.name)
            .navigationBarHidden(true)
    }
}

class Service {
    let ipAddress = "172.18.23.27:9090"
    let conversationId = "10.0.2.2"
    let currentUser = "participant2"
    func fetchMessages(conversationId: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let url = URL(string: "http://\(ipAddress)/conversations/\(conversationId)/messages")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, error)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    completion(json, nil)
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    func sendMessage(conversationId: String, message: String, type: String) {
        let url = URL(string: "http://\(ipAddress)/conversations/\(conversationId)/messages")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let parameters: [String: Any] = [
            "sender": currentUser,
            "content": message,
            "conversation": conversationId,
            "type": type
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print("Error sending message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            print("Message sent successfully")
        }.resume()
    }
    func fetchConversations(currentUser: String, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        let url = URL(string: "http://\(ipAddress)/conversation/\(currentUser)")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, error)
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    completion(jsonResponse, nil)
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    func createOrGetConversation(clickedUserId: String,  completion: @escaping (String?, Error?) -> Void) {
        let url = URL(string: "http://\(ipAddress)/conversation/\(currentUser)/\(clickedUserId)")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, error)
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let conversationId = jsonResponse["_id"] as? String {
                    completion(conversationId, nil)
                    
                } else {
                    completion(nil, NSError(domain: "ServiceError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create or get conversation"]))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    func addReaction( messageId: String, reaction: String) {
        let url = URL(string: "http://\(ipAddress)/message/\(messageId)/emoji")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let parameters: [String: Any] = [
            "emoji": reaction, // Ensure that the key is "emoji"
            "user": currentUser
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print("Error adding reaction: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            print("Reaction added successfully")
        }.resume()
        
    }
    func deleteConversation(conversationId: String, completion: @escaping (Error?) -> Void) {
        let url = URL(string: "http://\(ipAddress)/conversations/\(conversationId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                completion(error)
                return
            }
            
            completion(nil)
        }.resume()
    }


    func sendAttachment(conversationId: String, fileURL: URL, completion: @escaping (String?, Error?) -> Void) {
        let url = URL(string: "http://\(ipAddress)/conversations/\(conversationId)/attachments")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = NSMutableData()

        // Add file data to the request body
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"attachment\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(try! Data(contentsOf: fileURL))
        body.append("\r\n".data(using: .utf8)!)

        // Final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body as Data

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, error)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let url = json["url"] as? String {
                    completion(url, nil)
                } else {
                    completion(nil, NSError(domain: "ServiceError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to send attachment"]))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }

}
