import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var notes: [Note] = []
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var isAddingNote = false
    @State private var sortingOption: SortingOption = .title
    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    
    enum SortingOption: String, CaseIterable, Identifiable {
        case title = "Title"
        case date = "Date"
        
        var id: String { self.rawValue }
    }
    
    var sortedNotes: [Note] {
        switch sortingOption {
        case .title:
            return notes.sorted { $0.title < $1.title }
        case .date:
            return notes.sorted { $0.date < $1.date }
        }
    }
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return sortedNotes
        } else {
            return sortedNotes.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.green]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Picker("Sort by:", selection: $sortingOption) {
                        ForEach(SortingOption.allCases) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    List {
                        ForEach(filteredNotes) { note in
                            NavigationLink(destination: EditNoteView(note: note, onSave: { updatedNote in
                                if let index = self.notes.firstIndex(where: { $0.id == updatedNote.id }) {
                                    self.notes[index] = updatedNote
                                    saveNotes() // Save the updated note
                                }
                            })) {
                                HStack {
                                    Text(note.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(note.date.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete(perform: deleteNote)
                    }
                    .listStyle(PlainListStyle())
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .opacity(0.8)
                            .shadow(radius: 5)
                    )
                    
                    Button(action: {
                        // Toggle the state to show/hide the add note view
                        isAddingNote.toggle()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Note")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Notes")
            .sheet(isPresented: $isAddingNote) {
                EditNoteView(note: nil) { newNote in
                    self.notes.append(newNote)
                    self.isAddingNote = false
                    saveNotes() // Save the newly added note
                }
            }
        }
        .onAppear {
            // Load saved notes
            loadNotes()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func deleteNote(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        saveNotes() // Save the updated notes after deletion
    }
    
    func saveNotes() {
        do {
            let encoder = JSONEncoder()
            let encodedNotes = try encoder.encode(notes)
            UserDefaults.standard.set(encodedNotes, forKey: "notes")
        } catch {
            print("Error encoding notes: \(error.localizedDescription)")
        }
    }
    
    func loadNotes() {
        if let encodedNotes = UserDefaults.standard.data(forKey: "notes") {
            let decoder = JSONDecoder()
            do {
                notes = try decoder.decode([Note].self, from: encodedNotes)
            } catch {
                print("Error decoding notes: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct EditNoteView: View {
    @State private var updatedNoteTitle: String
    @State private var updatedNoteContent: String
    @State private var reminderDate: Date = Date()
    @State private var isDatePickerVisible = false // State variable to toggle DatePicker visibility

    let note: Note?
    let onSave: (Note) -> Void
    
    init(note: Note?, onSave: @escaping (Note) -> Void) {
        self.note = note
        self.onSave = onSave
        
        if let note = note {
            self._updatedNoteTitle = State(initialValue: note.title)
            self._updatedNoteContent = State(initialValue: note.content)
            self._reminderDate = State(initialValue: note.reminderDate ?? Date())
        } else {
            self._updatedNoteTitle = State(initialValue: "")
            self._updatedNoteContent = State(initialValue: "")
        }
    }
    
    var body: some View {
        VStack {
            TextField("Title", text: $updatedNoteTitle)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
            
            TextEditor(text: $updatedNoteContent)
                .frame(minHeight: 200)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
            
            Button(action: {
                isDatePickerVisible.toggle() // Toggle visibility of DatePicker
            }) {
                HStack {
                    Image(systemName: "clock")
                    Text("Set Reminder")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding()
            
            if isDatePickerVisible {
                DatePicker("Reminder", selection: $reminderDate, in: Date()...)
                    .datePickerStyle(DefaultDatePickerStyle())
                    .padding()
            }
            
            Button("Save") {
                let updatedNote = Note(id: note?.id ?? UUID(), title: updatedNoteTitle, content: updatedNoteContent, date: note?.date ?? Date(), reminderDate: reminderDate)
                onSave(updatedNote)
                scheduleNotification(for: updatedNote)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(10)
            .padding()
        }
    }
    
    func scheduleNotification(for note: Note) {
        if let reminderDate = note.reminderDate {
            let content = UNMutableNotificationContent()
            content.title = "Note Reminder"
            content.body = "Don't forget about your note: \(note.title)"
            content.sound = UNNotificationSound.default
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: note.id.uuidString, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
}



struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            TextField("Search", text: $text)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
                .padding(.horizontal, 10)
            
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Text("Cancel")
                        .padding(.trailing, 10)
                }
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
    }
}

struct Note: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var date: Date
    var reminderDate: Date?
}

var showReminderPicker = false
