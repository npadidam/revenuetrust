/**
 * @description Safe formula evaluator for custom commission calculations.
 *              Supports: arithmetic (+, -, *, /), comparisons (>, <, >=, <=, ==, !=),
 *              conditionals (IF/THEN/ELSE), field references, and functions (MIN, MAX, ABS, ROUND).
 *
 *              NOT a general-purpose Apex evaluator — intentionally limited to:
 *              - Numeric and boolean operations only
 *              - No DML, no SOQL, no method calls
 *              - No string manipulation (commission formulas are numeric)
 *              - Sandboxed: cannot access system resources
 *
 *              Example formulas:
 *              - Simple: Amount * 0.05
 *              - With condition: IF(Amount > 100000, Amount * 0.08, Amount * 0.05)
 *              - With COGS: (Amount - COGS) * 0.05
 *              - Multi-tier: IF(Attainment > 150, Amount * 0.15, IF(Attainment > 100, Amount * 0.12, Amount * 0.08))
 *              - With functions: MIN(Amount * 0.10, 50000)
 *              - Complex: (Amount - COGS) * IF(Term > 12, 0.08, 0.05) * IF(Is_Partner, 0.5, 1.0)
 */
public with sharing class FormulaEvaluator {

    public class FormulaResult {
        public Decimal value;
        public Boolean success;
        public String errorMessage;

        public FormulaResult(Decimal val) {
            this.value = val;
            this.success = true;
        }

        public FormulaResult(String error) {
            this.value = 0;
            this.success = false;
            this.errorMessage = error;
        }
    }

    /**
     * Evaluate a formula expression with the given variable values.
     */
    public static FormulaResult evaluate(String expression, Map<String, Decimal> variables) {
        if (String.isBlank(expression)) {
            return new FormulaResult('Empty formula expression');
        }

        try {
            // Validate expression safety (no dangerous patterns)
            validateSafety(expression);

            // Substitute variables
            String resolved = substituteVariables(expression, variables);

            // Parse and evaluate
            Decimal result = parseExpression(resolved.trim());
            return new FormulaResult(result);

        } catch (FormulaException e) {
            return new FormulaResult(e.getMessage());
        } catch (Exception e) {
            return new FormulaResult('Formula evaluation error: ' + e.getMessage());
        }
    }

    /**
     * Evaluate a Commission_Formula__c record against a pipeline record.
     */
    public static FormulaResult evaluateFormula(Commission_Formula__c formula, SObject record) {
        // 1. Check conditions
        if (String.isNotBlank(formula.Conditions__c)) {
            if (!evaluateConditions(formula.Conditions__c, record)) {
                return new FormulaResult('Conditions not met');
            }
        }

        // 2. Resolve variables
        Map<String, Decimal> variables = resolveVariables(formula.Variables__c, record);

        // 3. Evaluate expression
        return evaluate(formula.Formula_Expression__c, variables);
    }

    /**
     * Check if conditions are met for this formula to apply.
     */
    public static Boolean evaluateConditions(String conditionsJson, SObject record) {
        if (String.isBlank(conditionsJson)) {
            return true;
        }

        try {
            List<Object> conditions = (List<Object>) JSON.deserializeUntyped(conditionsJson);
            for (Object condObj : conditions) {
                Map<String, Object> cond = (Map<String, Object>) condObj;
                String fieldName = (String) cond.get('field');
                String operator = (String) cond.get('operator');
                Object expectedValue = cond.get('value');

                Object actualValue;
                try {
                    actualValue = record.get(fieldName);
                } catch (Exception e) {
                    actualValue = PipelineObjectService.getDynamicField(record, fieldName);
                }

                if (!evaluateCondition(actualValue, operator, expectedValue)) {
                    return false;
                }
            }
            return true;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'FormulaEvaluator: Failed to evaluate conditions: ' + e.getMessage());
            return false;
        }
    }

    /**
     * Resolve variable definitions from JSON against a pipeline record.
     */
    public static Map<String, Decimal> resolveVariables(String variablesJson, SObject record) {
        Map<String, Decimal> variables = new Map<String, Decimal>();

        if (String.isBlank(variablesJson)) {
            return variables;
        }

        try {
            List<Object> varDefs = (List<Object>) JSON.deserializeUntyped(variablesJson);
            for (Object varObj : varDefs) {
                Map<String, Object> varDef = (Map<String, Object>) varObj;
                String varName = (String) varDef.get('name');
                String source = (String) varDef.get('source');

                Decimal value = 0;

                if (source != null && source.startsWith('Pipeline.')) {
                    // Use PipelineObjectService for logical field mapping
                    Object rawVal = PipelineObjectService.getFieldValue(record, source);
                    value = toDecimal(rawVal);
                } else if (source != null) {
                    // Direct field reference on the record
                    String fieldName = source.contains('.') ? source.split('\\.')[1] : source;
                    Object rawVal = PipelineObjectService.getDynamicField(record, fieldName);
                    value = toDecimal(rawVal);
                }

                variables.put(varName, value);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'FormulaEvaluator: Failed to resolve variables: ' + e.getMessage());
        }

        return variables;
    }

    // ── Expression Parser (recursive descent) ───────────────────────────

    private static Decimal parseExpression(String expr) {
        // Handle IF(condition, trueValue, falseValue)
        if (expr.toUpperCase().startsWith('IF(')) {
            return parseIf(expr);
        }

        // Handle MIN(a, b) and MAX(a, b)
        if (expr.toUpperCase().startsWith('MIN(') || expr.toUpperCase().startsWith('MAX(')) {
            return parseMinMax(expr);
        }

        // Handle ABS(x)
        if (expr.toUpperCase().startsWith('ABS(')) {
            String innerContent = extractParenContent(expr);
            return Math.abs(parseExpression(innerContent));
        }

        // Handle ROUND(x, decimals)
        if (expr.toUpperCase().startsWith('ROUND(')) {
            return parseRound(expr);
        }

        // Handle addition/subtraction (lowest precedence)
        return parseAddSub(expr);
    }

    private static Decimal parseAddSub(String expr) {
        // Find the last + or - not inside parentheses
        Integer depth = 0;
        Integer lastOpPos = -1;
        String lastOp = null;

        for (Integer i = expr.length() - 1; i >= 0; i--) {
            String ch = expr.substring(i, i + 1);
            if (ch == ')') {
                depth++;
            }
            if (ch == '(') {
                depth--;
            }
            if (depth == 0 && (ch == '+' || ch == '-') && i > 0) {
                // Check it's not part of a number (e.g., -5 at start)
                String prev = expr.substring(i - 1, i).trim();
                if (prev != '' && prev != '*' && prev != '/' && prev != '(' && prev != ',') {
                    lastOpPos = i;
                    lastOp = ch;
                    break;
                }
            }
        }

        if (lastOpPos > 0) {
            Decimal left = parseExpression(expr.substring(0, lastOpPos).trim());
            Decimal right = parseExpression(expr.substring(lastOpPos + 1).trim());
            return lastOp == '+' ? left + right : left - right;
        }

        return parseMulDiv(expr);
    }

    private static Decimal parseMulDiv(String expr) {
        Integer depth = 0;
        Integer lastOpPos = -1;
        String lastOp = null;

        for (Integer i = expr.length() - 1; i >= 0; i--) {
            String ch = expr.substring(i, i + 1);
            if (ch == ')') {
                depth++;
            }
            if (ch == '(') {
                depth--;
            }
            if (depth == 0 && (ch == '*' || ch == '/')) {
                lastOpPos = i;
                lastOp = ch;
                break;
            }
        }

        if (lastOpPos > 0) {
            Decimal left = parseExpression(expr.substring(0, lastOpPos).trim());
            Decimal right = parseExpression(expr.substring(lastOpPos + 1).trim());
            if (lastOp == '*') {
                return left * right;
            }
            if (right == 0) {
                return 0; // Safe division by zero
            }
            return left / right;
        }

        return parseAtom(expr);
    }

    private static Decimal parseAtom(String expr) {
        expr = expr.trim();

        // Remove outer parentheses
        if (expr.startsWith('(') && expr.endsWith(')')) {
            return parseExpression(expr.substring(1, expr.length() - 1));
        }

        // Try parsing as number
        try {
            return Decimal.valueOf(expr);
        } catch (Exception e) {
            throw new FormulaException('Cannot parse: "' + expr + '"');
        }
    }

    private static Decimal parseIf(String expr) {
        String content = extractParenContent(expr);
        List<String> parts = splitTopLevel(content);
        if (parts.size() != 3) {
            throw new FormulaException('IF requires 3 arguments: IF(condition, trueValue, falseValue)');
        }

        Boolean condition = evaluateComparison(parts[0].trim());
        return condition ? parseExpression(parts[1].trim()) : parseExpression(parts[2].trim());
    }

    private static Decimal parseMinMax(String expr) {
        Boolean isMin = expr.toUpperCase().startsWith('MIN(');
        String content = extractParenContent(expr);
        List<String> parts = splitTopLevel(content);

        Decimal a = parseExpression(parts[0].trim());
        Decimal b = parseExpression(parts[1].trim());
        return isMin ? Math.min(a, b) : Math.max(a, b);
    }

    private static Decimal parseRound(String expr) {
        String content = extractParenContent(expr);
        List<String> parts = splitTopLevel(content);
        Decimal value = parseExpression(parts[0].trim());
        Integer decimals = parts.size() > 1 ? Integer.valueOf(parts[1].trim()) : 2;
        return value.setScale(decimals, RoundingMode.HALF_UP);
    }

    private static Boolean evaluateComparison(String expr) {
        // Parse: left operator right
        String[] operators = new String[]{'>=', '<=', '!=', '==', '>', '<'};
        for (String op : operators) {
            Integer pos = expr.indexOf(op);
            if (pos > 0) {
                Decimal left = parseExpression(expr.substring(0, pos).trim());
                Decimal right = parseExpression(expr.substring(pos + op.length()).trim());
                if (op == '>') return left > right;
                if (op == '<') return left < right;
                if (op == '>=') return left >= right;
                if (op == '<=') return left <= right;
                if (op == '==') return left == right;
                if (op == '!=') return left != right;
            }
        }

        // Treat as boolean: non-zero = true
        return parseExpression(expr) != 0;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static String substituteVariables(String expression, Map<String, Decimal> variables) {
        String result = expression;
        // Sort by length descending to avoid partial replacements
        List<String> sortedKeys = new List<String>(variables.keySet());
        sortedKeys.sort();

        // Replace longest names first
        for (Integer i = sortedKeys.size() - 1; i >= 0; i--) {
            String varName = sortedKeys[i];
            Decimal value = variables.get(varName);
            result = result.replace(varName, String.valueOf(value != null ? value : 0));
        }
        return result;
    }

    private static void validateSafety(String expression) {
        String upper = expression.toUpperCase();
        String[] forbidden = new String[]{
            'DATABASE.', 'SYSTEM.', 'USERINFO.', 'INSERT ', 'UPDATE ', 'DELETE ',
            'UPSERT ', 'SELECT ', 'FROM ', 'WHERE ', 'HTTP', 'CALLOUT',
            'TYPE.FORNAME', 'APEXPAGES', 'MESSAGING.'
        };
        for (String f : forbidden) {
            if (upper.contains(f)) {
                throw new FormulaException('Unsafe expression: contains forbidden keyword "' + f.trim() + '"');
            }
        }
    }

    private static Boolean evaluateCondition(Object actualValue, String operator, Object expectedValue) {
        String actual = actualValue != null ? String.valueOf(actualValue) : '';
        String expected = expectedValue != null ? String.valueOf(expectedValue) : '';

        switch on operator {
            when 'equals', '==' {
                return actual.equalsIgnoreCase(expected);
            }
            when 'notEquals', '!=' {
                return !actual.equalsIgnoreCase(expected);
            }
            when 'contains' {
                return actual.containsIgnoreCase(expected);
            }
            when 'greaterThan', '>' {
                try {
                    return Decimal.valueOf(actual) > Decimal.valueOf(expected);
                } catch (Exception e) {
                    return false;
                }
            }
            when 'lessThan', '<' {
                try {
                    return Decimal.valueOf(actual) < Decimal.valueOf(expected);
                } catch (Exception e) {
                    return false;
                }
            }
            when 'greaterOrEqual', '>=' {
                try {
                    return Decimal.valueOf(actual) >= Decimal.valueOf(expected);
                } catch (Exception e) {
                    return false;
                }
            }
            when 'lessOrEqual', '<=' {
                try {
                    return Decimal.valueOf(actual) <= Decimal.valueOf(expected);
                } catch (Exception e) {
                    return false;
                }
            }
            when 'isNull' {
                return actualValue == null;
            }
            when 'isNotNull' {
                return actualValue != null;
            }
            when else {
                return false;
            }
        }
    }

    private static String extractParenContent(String expr) {
        Integer startPos = expr.indexOf('(');
        Integer endPos = expr.lastIndexOf(')');
        if (startPos < 0 || endPos < 0) {
            throw new FormulaException('Missing parentheses in: ' + expr);
        }
        return expr.substring(startPos + 1, endPos);
    }

    private static List<String> splitTopLevel(String expr) {
        List<String> parts = new List<String>();
        Integer depth = 0;
        Integer lastSplit = 0;

        for (Integer i = 0; i < expr.length(); i++) {
            String ch = expr.substring(i, i + 1);
            if (ch == '(') {
                depth++;
            }
            if (ch == ')') {
                depth--;
            }
            if (ch == ',' && depth == 0) {
                parts.add(expr.substring(lastSplit, i));
                lastSplit = i + 1;
            }
        }
        parts.add(expr.substring(lastSplit));
        return parts;
    }

    private static Decimal toDecimal(Object val) {
        if (val == null) return 0;
        if (val instanceof Decimal) return (Decimal) val;
        if (val instanceof Integer) return Decimal.valueOf((Integer) val);
        if (val instanceof Double) return Decimal.valueOf((Double) val);
        if (val instanceof Long) return Decimal.valueOf((Long) val);
        try {
            return Decimal.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return 0;
        }
    }

    public class FormulaException extends Exception {}
}
