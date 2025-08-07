# ✅ Checklist de Accesibilidad para Nuevas Features

## Antes de Implementar una Nueva Feature

### **📋 Diseño y Planificación**

#### **Contraste de Colores**
- [ ] Verificar ratio de contraste mínimo 4.5:1 para texto normal
- [ ] Verificar ratio de contraste mínimo 3:1 para texto grande (>18pt)
- [ ] Probar contraste en ambos temas (light/dark)
- [ ] Verificar contraste de elementos interactivos (botones, enlaces)
- [ ] Documentar combinaciones de colores aprobadas

#### **Tamaños y Espaciado**
- [ ] Elementos interactivos mínimo 44x44 pts
- [ ] Espaciado suficiente entre elementos interactivos
- [ ] Texto legible en tamaño base (16pt mínimo para contenido)
- [ ] Planificar layout para Dynamic Type hasta 200%

#### **Navegación y Estructura**
- [ ] Definir jerarquía clara de información
- [ ] Planificar orden lógico de navegación VoiceOver
- [ ] Identificar elementos decorativos vs funcionales
- [ ] Agrupar información relacionada

### **💻 Durante la Implementación**

#### **Etiquetas de Accesibilidad**
- [ ] Agregar `accessibilityLabel` descriptivo para elementos interactivos
- [ ] Agregar `accessibilityHint` para explicar acción esperada
- [ ] Usar `accessibilityValue` para información de estado
- [ ] Aplicar `accessibilityTraits` apropiados (`.isButton`, `.isHeader`, etc.)

#### **Agrupación y Estructura**
- [ ] Usar `accessibilityElement(children: .combine)` para agrupar info relacionada
- [ ] Usar `accessibilityHidden(true)` para elementos decorativos
- [ ] Marcar headers con `accessibilityAddTraits(.isHeader)`
- [ ] Crear agrupaciones lógicas con `accessibilityElement(children: .contain)`

#### **Dynamic Type y Fuentes**
- [ ] Usar `Font.cappedDynamicSystem()` en lugar de `.system()`
- [ ] Aplicar `.dynamicTypeSupport(maxLines:)` a textos
- [ ] Usar `DynamicTypeSize.adjustedSpacing()` para espaciado
- [ ] Usar `DynamicTypeSize.adjustedPadding()` para padding
- [ ] Implementar límites máximos y mínimos razonables

#### **Estados de Interacción**
- [ ] Estados de carga con `accessibilityLoadingState()`
- [ ] Estados de error con `accessibilityErrorState()`
- [ ] Feedback claro para acciones completadas
- [ ] Indicadores visuales de estado (activo, seleccionado, etc.)

### **🧪 Testing Obligatorio**

#### **Testing VoiceOver**
- [ ] Activar VoiceOver y navegar toda la feature
- [ ] Verificar orden lógico de navegación
- [ ] Confirmar que toda información importante es leída
- [ ] Verificar que elementos decorativos NO son leídos
- [ ] Probar activación de elementos interactivos

#### **Testing Dynamic Type**
- [ ] Probar tamaños de texto desde pequeño hasta AX5
- [ ] Verificar que no hay solapamiento de elementos
- [ ] Confirmar que texto no se corta ni sale de pantalla
- [ ] Verificar que botones mantienen tamaño mínimo
- [ ] Probar scrolling vertical si es necesario

#### **Testing de Contraste**
- [ ] Usar herramientas automáticas (Color Oracle, Contrast)
- [ ] Probar en condiciones de luz real
- [ ] Verificar con simuladores de daltonismo
- [ ] Probar en dispositivos reales

#### **Testing de Estados**
- [ ] Estados de carga (loading, error, vacío)
- [ ] Estados de interacción (pressed, focused, disabled)
- [ ] Transiciones entre estados
- [ ] Feedback visual y auditivo

### **📚 Documentación Requerida**

#### **En el Código**
- [ ] Comentarios explicando decisiones de accesibilidad
- [ ] Documentar ratios de contraste usados
- [ ] Explicar agrupaciones de VoiceOver complejas
- [ ] Notas sobre casos especiales o limitaciones

#### **En Testing**
- [ ] Casos de prueba específicos de accesibilidad
- [ ] Capturas de pantalla con VoiceOver activado
- [ ] Documentar comportamiento esperado
- [ ] Registrar problemas conocidos y workarounds

## 🚨 Red Flags - Revisar Inmediatamente

### **Problemas Críticos**
- [ ] Texto con contraste < 4.5:1
- [ ] Elementos interactivos < 44x44 pts
- [ ] Información importante solo comunicada por color
- [ ] Elementos interactivos sin etiquetas de accesibilidad
- [ ] Texto que se corta con Dynamic Type grande

### **Problemas de Usabilidad**
- [ ] Orden de VoiceOver ilógico o confuso
- [ ] Demasiados elementos agrupados (más de 5 por grupo)
- [ ] Labels genéricos ("Botón", "Imagen", "Texto")
- [ ] Estados de carga sin feedback accesible
- [ ] Animaciones que no pueden deshabilitarse

## 🎯 Definición de "Listo para Producción"

Una feature NO puede considerarse completa hasta que:

### **✅ Cumplimiento Técnico**
- [x] 100% de elementos interactivos con labels apropiados
- [x] 100% de contraste cumple WCAG 2.1 AA
- [x] 100% de elementos soportan Dynamic Type
- [x] 100% de touch targets cumplen tamaño mínimo

### **✅ Testing Completado**
- [x] Testing VoiceOver completo y documentado
- [x] Testing Dynamic Type en todos los tamaños
- [x] Verificación de contraste con herramientas
- [x] Testing en dispositivos reales

### **✅ Documentación**
- [x] Guía de accesibilidad actualizada
- [x] Casos de prueba documentados
- [x] Decisiones de diseño justificadas
- [x] Problemas conocidos registrados

## 🛠️ Herramientas Recomendadas

### **Para Desarrolladores**
- **Xcode Accessibility Inspector**: Testing integrado
- **Voice Control**: Testing de navegación por voz
- **Switch Control**: Testing con dispositivos adaptativos
- **Color Oracle**: Simulador de daltonismo

### **Para Diseñadores**
- **Figma Contrast Plugin**: Verificación de contraste
- **Stark**: Plugin de accesibilidad
- **WebAIM Contrast Checker**: Herramienta online
- **Colour Contrast Analyser**: App gratuita

### **Para QA**
- **WAVE**: Evaluador de accesibilidad web
- **axe**: Herramientas de testing automático
- **Pa11y**: Testing de línea de comandos
- **Lighthouse**: Auditorías de accesibilidad

## 📞 Contactos y Recursos

### **Equipo de Accesibilidad**
- **Lead Developer**: Responsable de implementación técnica
- **UX Designer**: Responsable de experiencia de usuario
- **QA Engineer**: Responsable de testing y validación

### **Recursos Externos**
- **Apple Human Interface Guidelines**: Guías oficiales
- **WCAG 2.1 Guidelines**: Estándares internacionales  
- **WebAIM**: Recursos y herramientas
- **A11Y Project**: Checklist y mejores prácticas

---

**💡 Recuerda**: La accesibilidad no es opcional. Es un derecho fundamental y una responsabilidad legal.

**🎯 Objetivo**: Crear experiencias inclusivas que funcionen para todos los usuarios, independientemente de sus capacidades.

**📅 Revisión**: Este checklist debe revisarse trimestralmente y actualizarse según nuevos estándares y herramientas.