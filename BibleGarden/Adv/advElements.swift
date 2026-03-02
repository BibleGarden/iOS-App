import SwiftUI

// Nice toggle buttons
@ViewBuilder 
func viewSegmentedButtons(arr: [String], selIndex: Int, baseColor: Color, bgColor: Color, closure:@escaping (_ selectedIndex: Int) -> Void) -> some View {
    
    
    let columns = Array(repeating: GridItem(spacing: 1), count:arr.count)
    LazyVGrid(columns: columns, spacing: 1.0) {
        
        ForEach(Array(arr.enumerated()), id: \.element) { index, name in
            
            
            ZStack {
                
                Rectangle()
                    .foregroundColor(index == selIndex ? baseColor : bgColor)
                
                Text(name)
                    .padding(.vertical, 10)
                    .font(.callout)
                    .foregroundColor(Color("localAccentColor"))
                
            }
            .contentShape(Rectangle()) // Ensure the entire area is tappable
            .onTapGesture {
                withAnimation {
                    closure(index)
                }
            }
            
        }
         
    }
    .foregroundColor(baseColor)
    .font(.callout)
    .cornerRadius(globalCornerRadius)
     
}

// Group header
@ViewBuilder
func viewGroupHeader(text: String) -> some View {
    Text(text)
        .textCase(.uppercase)
        .padding(.top, 30)
        .padding(.bottom, 10)
        .foregroundColor(Color("localAccentColor").opacity(0.5))
        .frame(maxWidth: .infinity, alignment: .leading)
}

// List selection
@ViewBuilder
func viewSelectList(texts: [String], keys: [String], selectedKey: Binding<String>,
                    descriptions: [String] = [],
                    onSelect: @escaping (Int) -> Void = { _ in }) -> some View {
    LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(texts.indices, id: \.self) { index in
            let text = texts[index]
            let key = keys[index]
            let description = index < descriptions.count ? descriptions[index] : ""
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(selectedKey.wrappedValue == key ? Color("Mustard") : .white)
                    if !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 10)
                Spacer()
                if selectedKey.wrappedValue == key {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color("Mustard"))
                }
            }
            .background(Color("DarkGreen"))
            .contentShape(Rectangle())
            .onTapGesture {
                selectedKey.wrappedValue = key
                onSelect(index)
            }
        }
    }
}

// List selection with preview button
@ViewBuilder
func viewSelectListWithPreview(texts: [String], keys: [String], selectedKey: Binding<String>,
                                descriptions: [String] = [],
                                onSelect: @escaping (Int) -> Void = { _ in },
                                onPreview: @escaping (Int) -> Void,
                                isPlaying: @escaping (Int) -> Bool) -> some View {
    LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(texts.indices, id: \.self) { index in
            let text = texts[index]
            let key = keys[index]
            let description = index < descriptions.count ? descriptions[index] : ""
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(selectedKey.wrappedValue == key ? Color("Mustard") : .white)
                        
                        if !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    Spacer()
                    
                    // Preview button
                    Button {
                        onPreview(index)
                    } label: {
                        Image(systemName: isPlaying(index) ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundColor(Color("localAccentColor"))
                            .font(.system(size: 24))
                    }
                    .frame(width: 32)
                    .padding(.top, 10)
                    
                    // Checkmark with fixed width
                    Image(systemName: "checkmark")
                        .foregroundColor(Color("Mustard"))
                        .frame(width: 20)
                        .padding(.top, 10)
                        .opacity(selectedKey.wrappedValue == key ? 1 : 0)
                }
            }
            .background(Color("DarkGreen"))
            .contentShape(Rectangle())
            .onTapGesture {
                selectedKey.wrappedValue = key
                onSelect(index)
            }
        }
    }
}

// Selection from dropdown
@ViewBuilder
func viewEnumPicker<T: RawRepresentable & CaseIterable & Identifiable & Hashable & DisplayNameProvider>(
    title: String,
    selection: Binding<T>
) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection, T.AllCases.Element == T {
    Menu {
        Picker("", selection: selection) {
            ForEach(Array(T.allCases), id: \.self) { value in
                Text(value.displayName).tag(value)
            }
        }
    } label: {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.down")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(Color("DarkGreen-light").opacity(0.6))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
    }
}
