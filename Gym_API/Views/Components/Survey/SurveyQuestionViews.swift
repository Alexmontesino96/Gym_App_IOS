import SwiftUI

// MARK: - Text Question View
struct TextQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            GlassmorphicTextField(
                placeholder: question.placeholder ?? "Enter your answer",
                text: Binding(
                    get: { answer.textAnswer ?? "" },
                    set: { answer.textAnswer = $0 }
                ),
                icon: "text.cursor"
            )
            .environmentObject(themeManager)
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let maxLength = question.maxLength {
                Text("\((answer.textAnswer ?? "").count)/\(maxLength)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Textarea Question View
struct TextareaQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            GlassmorphicTextEditor(
                placeholder: question.placeholder ?? "Enter your detailed answer",
                text: Binding(
                    get: { answer.textAnswer ?? "" },
                    set: { answer.textAnswer = $0 }
                ),
                minHeight: 120
            )
            .environmentObject(themeManager)
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let maxLength = question.maxLength {
                Text("\((answer.textAnswer ?? "").count)/\(maxLength)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Radio Question View
struct RadioQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @State private var showOtherField = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            if let choices = question.choices {
                VStack(spacing: 8) {
                    ForEach(choices) { choice in
                        AnimatedRadioButton(
                            label: choice.choiceText,
                            isSelected: answer.choiceId == choice.id,
                            action: {
                                answer.choiceId = choice.id
                                showOtherField = false
                            }
                        )
                        .environmentObject(themeManager)
                    }
                }
                
                // Other option handling
                if question.allowOther == true {
                    AnimatedRadioButton(
                        label: "Other",
                        isSelected: showOtherField,
                        action: {
                            showOtherField = true
                            answer.choiceId = nil
                        }
                    )
                    .environmentObject(themeManager)
                    
                    if showOtherField {
                        GlassmorphicTextField(
                            placeholder: "Please specify",
                            text: Binding(
                                get: { answer.otherText ?? "" },
                                set: { answer.otherText = $0 }
                            ),
                            icon: "pencil"
                        )
                        .environmentObject(themeManager)
                        .padding(.leading, 32)
                    }
                }
            }
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Checkbox Question View
struct CheckboxQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @State private var selectedChoices: Set<Int> = []
    @State private var showOtherField = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            if let minSelections = question.minSelections,
               let maxSelections = question.maxSelections {
                HStack {
                    Text("Select \(minSelections) to \(maxSelections) options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(selectedChoices.count) selected")
                        .font(.caption)
                        .foregroundColor(selectedChoices.count >= maxSelections ? .orange : .secondary)
                }
            } else if let minSelections = question.minSelections {
                Text("Select at least \(minSelections) option\(minSelections > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let maxSelections = question.maxSelections {
                HStack {
                    Text("Select up to \(maxSelections) option\(maxSelections > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if selectedChoices.count >= maxSelections {
                        Text("Limit reached")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if let choices = question.choices {
                VStack(spacing: 8) {
                    ForEach(choices) { choice in
                        PulsatingCheckbox(
                            label: choice.choiceText,
                            isChecked: Binding(
                                get: { selectedChoices.contains(choice.id) },
                                set: { isChecked in
                                    if isChecked {
                                        // Check max selections limit
                                        if let max = question.maxSelections,
                                           selectedChoices.count >= max,
                                           !selectedChoices.contains(choice.id) {
                                            // Don't allow selecting more than max
                                            return
                                        }
                                        selectedChoices.insert(choice.id)
                                    } else {
                                        selectedChoices.remove(choice.id)
                                    }
                                    answer.choiceIds = Array(selectedChoices)
                                }
                            )
                        )
                        .environmentObject(themeManager)
                    }
                }
                
                if question.allowOther == true {
                    PulsatingCheckbox(
                        label: "Other",
                        isChecked: $showOtherField
                    )
                    .environmentObject(themeManager)
                    
                    if showOtherField {
                        GlassmorphicTextField(
                            placeholder: "Please specify",
                            text: Binding(
                                get: { answer.otherText ?? "" },
                                set: { answer.otherText = $0 }
                            ),
                            icon: "pencil"
                        )
                        .environmentObject(themeManager)
                        .padding(.leading, 32)
                    }
                }
            }
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            selectedChoices = Set(answer.choiceIds ?? [])
        }
    }
    
    private func toggleChoice(_ choiceId: Int) {
        if selectedChoices.contains(choiceId) {
            selectedChoices.remove(choiceId)
        } else {
            if let maxSelections = question.maxSelections,
               selectedChoices.count >= maxSelections {
                return
            }
            selectedChoices.insert(choiceId)
        }
        answer.choiceIds = Array(selectedChoices)
    }
}

// MARK: - Scale Question View
struct ScaleQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @EnvironmentObject var themeManager: ThemeManager
    
    var minValue: Double { question.minValue ?? 1 }
    var maxValue: Double { question.maxValue ?? 5 }
    var step: Double { question.step ?? 1 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            QuestionHeader(question: question)
            
            ModernScaleSlider(
                value: Binding(
                    get: { answer.numberAnswer ?? minValue },
                    set: { answer.numberAnswer = $0 }
                ),
                range: minValue...maxValue,
                step: step
            )
            .environmentObject(themeManager)
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - NPS Question View
struct NPSQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            QuestionHeader(question: question)
            
            NPSScaleView(
                value: Binding(
                    get: { 
                        if let num = answer.numberAnswer {
                            return Int(num)
                        }
                        return nil
                    },
                    set: { 
                        if let val = $0 {
                            answer.numberAnswer = Double(val)
                        } else {
                            answer.numberAnswer = nil
                        }
                    }
                )
            )
            .environmentObject(themeManager)
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Yes/No Question View
struct YesNoQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            YesNoToggle(
                value: $answer.booleanAnswer
            )
            .environmentObject(themeManager)
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Date Question View
struct DateQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @State private var selectedDate = Date()
    
    var dateRange: ClosedRange<Date> {
        let min = question.minDate ?? Date.distantPast
        let max = question.maxDate ?? Date.distantFuture
        return min...max
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            DatePicker(
                "Select date",
                selection: Binding(
                    get: { answer.dateAnswer ?? Date() },
                    set: { answer.dateAnswer = $0 }
                ),
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .labelsHidden()
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Number Question View
struct NumberQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @FocusState private var isFocused: Bool
    @State private var validationError: String?
    
    var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = question.decimalPlaces ?? 0
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            HStack {
                TextField(
                    "Enter number",
                    value: Binding(
                        get: { answer.numberAnswer },
                        set: { 
                            answer.numberAnswer = $0
                            validateNumber($0)
                        }
                    ),
                    formatter: numberFormatter
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(question.decimalPlaces ?? 0 > 0 ? .decimalPad : .numberPad)
                .focused($isFocused)
                
                if let minValue = question.minValue,
                   let maxValue = question.maxValue {
                    Text("(\(Int(minValue)) - \(Int(maxValue)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func validateNumber(_ value: Double?) {
        guard let value = value else {
            validationError = nil
            return
        }
        
        if let min = question.minValue, value < min {
            validationError = "Value must be at least \(Int(min))"
            return
        }
        
        if let max = question.maxValue, value > max {
            validationError = "Value must be at most \(Int(max))"
            return
        }
        
        validationError = nil
    }
}

// MARK: - Email Question View
struct EmailQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @FocusState private var isFocused: Bool
    @State private var isValidEmail = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            TextField(
                question.placeholder ?? "email@example.com",
                text: Binding(
                    get: { answer.textAnswer ?? "" },
                    set: { 
                        answer.textAnswer = $0
                        isValidEmail = isValidEmailFormat($0)
                    }
                )
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .focused($isFocused)
            
            if !isValidEmail && !(answer.textAnswer ?? "").isEmpty {
                Text("Please enter a valid email address")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func isValidEmailFormat(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// MARK: - Phone Question View
struct PhoneQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @FocusState private var isFocused: Bool
    @State private var isValidPhone = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            TextField(
                question.placeholder ?? "Enter phone number",
                text: Binding(
                    get: { answer.textAnswer ?? "" },
                    set: { 
                        answer.textAnswer = $0
                        isValidPhone = isValidPhoneFormat($0)
                    }
                )
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.phonePad)
            .focused($isFocused)
            
            if !isValidPhone && !(answer.textAnswer ?? "").isEmpty {
                Text("Please enter a valid phone number (min 10 digits)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func isValidPhoneFormat(_ phone: String) -> Bool {
        // Remove non-numeric characters for validation
        let numericOnly = phone.filter { $0.isNumber }
        // Most phone numbers have at least 10 digits
        return numericOnly.count >= 10 || phone.isEmpty
    }
}

// MARK: - Time Question View
struct TimeQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @State private var selectedTime = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            DatePicker(
                "Select time",
                selection: Binding(
                    get: {
                        if let timeString = answer.textAnswer,
                           let date = ISO8601DateFormatter().date(from: timeString) {
                            return date
                        }
                        return Date()
                    },
                    set: { newDate in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        answer.textAnswer = formatter.string(from: newDate)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(WheelDatePickerStyle())
            .labelsHidden()
            .frame(height: 150)
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Select (Dropdown) Question View
struct SelectQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    @State private var selectedChoice: QuestionChoice?
    @State private var showOtherField = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuestionHeader(question: question)
            
            if let choices = question.choices {
                Menu {
                    ForEach(choices) { choice in
                        Button(choice.choiceText) {
                            selectedChoice = choice
                            answer.choiceId = choice.id
                            showOtherField = false
                        }
                    }
                    
                    if question.allowOther == true {
                        Button("Other...") {
                            selectedChoice = nil
                            answer.choiceId = nil
                            showOtherField = true
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedChoice?.choiceText ?? (showOtherField ? "Other" : "Select an option"))
                            .foregroundColor(selectedChoice != nil || showOtherField ? .primary : .secondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if showOtherField {
                    TextField("Please specify", text: Binding(
                        get: { answer.otherText ?? "" },
                        set: { answer.otherText = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.top, 4)
                }
            }
            
            if let helpText = question.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            if let choiceId = answer.choiceId,
               let choices = question.choices {
                selectedChoice = choices.first { $0.id == choiceId }
            }
        }
    }
}

// MARK: - Question Header Component
struct QuestionHeader: View {
    let question: SurveyQuestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(question.questionText)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                
                if question.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.headline)
                }
            }
        }
    }
}

// MARK: - Main Question View Router
struct SurveyQuestionView: View {
    let question: SurveyQuestion
    @Binding var answer: SurveyAnswer
    
    var body: some View {
        Group {
            switch question.questionType {
            case .text:
                TextQuestionView(question: question, answer: $answer)
            case .textarea:
                TextareaQuestionView(question: question, answer: $answer)
            case .radio:
                RadioQuestionView(question: question, answer: $answer)
            case .checkbox:
                CheckboxQuestionView(question: question, answer: $answer)
            case .scale:
                ScaleQuestionView(question: question, answer: $answer)
            case .nps:
                NPSQuestionView(question: question, answer: $answer)
            case .yesNo:
                YesNoQuestionView(question: question, answer: $answer)
            case .date:
                DateQuestionView(question: question, answer: $answer)
            case .time:
                TimeQuestionView(question: question, answer: $answer)
            case .number:
                NumberQuestionView(question: question, answer: $answer)
            case .email:
                EmailQuestionView(question: question, answer: $answer)
            case .phone:
                PhoneQuestionView(question: question, answer: $answer)
            case .select:
                SelectQuestionView(question: question, answer: $answer)
            }
        }
    }
}