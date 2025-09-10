import SwiftUI

struct QuestionEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    let onSave: (SurveyQuestion) -> Void
    let existingQuestion: SurveyQuestion?
    
    @State private var questionText = ""
    @State private var questionType: QuestionType = .text
    @State private var isRequired = false
    @State private var helpText = ""
    @State private var placeholder = ""
    
    // Opciones para preguntas de selección
    @State private var choices: [TempChoice] = []
    @State private var newChoiceText = ""
    
    // Validación para preguntas numéricas
    @State private var hasMinValue = false
    @State private var minValue: Double = 0
    @State private var hasMaxValue = false
    @State private var maxValue: Double = 100
    
    // Validación para texto
    @State private var hasMinLength = false
    @State private var minLength: Int = 0
    @State private var hasMaxLength = false
    @State private var maxLength: Int = 500
    
    struct TempChoice: Identifiable {
        let id = UUID()
        var text: String
        var value: String?
    }
    
    init(existingQuestion: SurveyQuestion? = nil, onSave: @escaping (SurveyQuestion) -> Void) {
        self.existingQuestion = existingQuestion
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Texto de la pregunta
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Question Text", systemImage: "text.quote")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        TextField("Enter your question", text: $questionText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Tipo de pregunta
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Question Type", systemImage: "list.bullet")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Picker("Type", selection: $questionType) {
                            ForEach(QuestionType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: questionType) { newType in
                            // Si cambia a tipo de selección, agregar opciones por defecto
                            if [.radio, .checkbox, .select].contains(newType) && choices.isEmpty {
                                choices = [
                                    TempChoice(text: "Option 1", value: nil),
                                    TempChoice(text: "Option 2", value: nil)
                                ]
                            }
                        }
                    }
                    
                    // Requerida
                    Toggle(isOn: $isRequired) {
                        Label("Required Question", systemImage: "asterisk.circle")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    .tint(.accentColor)
                    
                    // Texto de ayuda
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Help Text (Optional)", systemImage: "questionmark.circle")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        TextField("Additional instructions", text: $helpText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Placeholder (para campos de texto)
                    if [.text, .textarea, .email, .phone, .number].contains(questionType) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Placeholder (Optional)", systemImage: "text.cursor")
                                .font(.headline)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            TextField("Placeholder text", text: $placeholder)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Opciones para preguntas de selección
                    if [.radio, .checkbox, .select].contains(questionType) {
                        choicesSection
                    }
                    
                    // Validación numérica
                    if [.number, .scale, .nps].contains(questionType) {
                        numericValidationSection
                    }
                    
                    // Validación de longitud de texto
                    if [.text, .textarea].contains(questionType) {
                        textValidationSection
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle(existingQuestion != nil ? "Edit Question" : "Add Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveQuestion() }
                        .disabled(questionText.isEmpty || !isValid())
                }
            }
        }
        .onAppear {
            loadExistingQuestion()
        }
    }
    
    // MARK: - Choices Section
    private var choicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Answer Choices", systemImage: "list.bullet.rectangle")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                HStack {
                    TextField("Choice \(index + 1)", text: $choices[index].text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: { removeChoice(choice) }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            HStack {
                TextField("New choice", text: $newChoiceText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addChoice) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .disabled(newChoiceText.isEmpty)
            }
            
            if choices.count < 2 {
                Text("Minimum 2 choices required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(10)
    }
    
    // MARK: - Numeric Validation Section
    private var numericValidationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Numeric Validation", systemImage: "number.circle")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Toggle("Set minimum value", isOn: $hasMinValue)
                .tint(.accentColor)
            
            if hasMinValue {
                HStack {
                    Text("Minimum:")
                    TextField("Min", value: $minValue, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 100)
                }
            }
            
            Toggle("Set maximum value", isOn: $hasMaxValue)
                .tint(.accentColor)
            
            if hasMaxValue {
                HStack {
                    Text("Maximum:")
                    TextField("Max", value: $maxValue, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 100)
                }
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(10)
    }
    
    // MARK: - Text Validation Section
    private var textValidationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Text Length Validation", systemImage: "textformat.size")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Toggle("Set minimum length", isOn: $hasMinLength)
                .tint(.accentColor)
            
            if hasMinLength {
                HStack {
                    Text("Min characters:")
                    TextField("Min", value: $minLength, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(width: 100)
                }
            }
            
            Toggle("Set maximum length", isOn: $hasMaxLength)
                .tint(.accentColor)
            
            if hasMaxLength {
                HStack {
                    Text("Max characters:")
                    TextField("Max", value: $maxLength, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(width: 100)
                }
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(10)
    }
    
    // MARK: - Methods
    
    private func loadExistingQuestion() {
        guard let question = existingQuestion else { return }
        
        questionText = question.questionText
        questionType = question.questionType
        isRequired = question.isRequired
        helpText = question.helpText ?? ""
        placeholder = question.placeholder ?? ""
        
        // Cargar choices si existen
        if let existingChoices = question.choices {
            choices = existingChoices.map { choice in
                TempChoice(text: choice.choiceText, value: choice.choiceValue)
            }
        }
        
        // Cargar validaciones numéricas
        if let min = question.minValue {
            hasMinValue = true
            minValue = min
        }
        if let max = question.maxValue {
            hasMaxValue = true
            maxValue = max
        }
        
        // Cargar validaciones de texto
        if let min = question.minLength {
            hasMinLength = true
            minLength = min
        }
        if let max = question.maxLength {
            hasMaxLength = true
            maxLength = max
        }
    }
    
    private func addChoice() {
        choices.append(TempChoice(text: newChoiceText, value: nil))
        newChoiceText = ""
    }
    
    private func removeChoice(_ choice: TempChoice) {
        choices.removeAll { $0.id == choice.id }
    }
    
    private func isValid() -> Bool {
        // Validar que preguntas de selección tengan al menos 2 opciones
        if [.radio, .checkbox, .select].contains(questionType) {
            return choices.count >= 2
        }
        
        // Validar que min < max si ambos están establecidos
        if hasMinValue && hasMaxValue && minValue >= maxValue {
            return false
        }
        
        if hasMinLength && hasMaxLength && minLength >= maxLength {
            return false
        }
        
        return true
    }
    
    private func saveQuestion() {
        // Crear choices para la pregunta
        let questionChoices: [QuestionChoice]? = [.radio, .checkbox, .select].contains(questionType) 
            ? choices.enumerated().map { index, choice in
                QuestionChoice(
                    id: 0,
                    questionId: 0,
                    choiceText: choice.text,
                    choiceValue: choice.value,
                    order: index,
                    nextQuestionId: nil,
                    createdAt: nil
                )
            }
            : nil
        
        // Crear la pregunta
        let question = SurveyQuestion(
            id: existingQuestion?.id ?? 0,
            surveyId: existingQuestion?.surveyId ?? 0,
            questionText: questionText,
            questionType: questionType,
            isRequired: isRequired,
            order: existingQuestion?.order ?? 0,
            helpText: helpText.isEmpty ? nil : helpText,
            minValue: hasMinValue ? minValue : nil,
            maxValue: hasMaxValue ? maxValue : nil,
            minLength: hasMinLength ? minLength : nil,
            maxLength: hasMaxLength ? maxLength : nil,
            placeholder: placeholder.isEmpty ? nil : placeholder,
            regexValidation: nil,
            regexErrorMessage: nil,
            dependsOnQuestionId: nil,
            dependsOnAnswer: nil,
            choices: questionChoices,
            minSelections: nil,
            maxSelections: nil,
            allowOther: false,
            decimalPlaces: nil,
            step: nil,
            labels: nil,
            minDate: nil,
            maxDate: nil,
            format: nil,
            createdAt: nil,
            updatedAt: nil
        )
        
        onSave(question)
        dismiss()
    }
}

// Preview
struct QuestionEditorView_Previews: PreviewProvider {
    static var previews: some View {
        QuestionEditorView { _ in }
            .environmentObject(ThemeManager())
    }
}