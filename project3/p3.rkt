; Hun Jae Lee, Daniel Yakobian, Justin Wang
; EECS345 Programming Language Concepts, Project 3

; Note: We used the student sample solution to complete project 3.

; Load the parser
; (load "simpleParser.scm") obsolete
(load "functionParser.scm")

(define interpret
  (lambda (filename)
    (M_state-functionCall '(funcall main) (interpret_parsed (parser filename) '((()) (()))))))

(define interpret_parsed
  (lambda (statements state)
    (cond
      ((null? statements) state)
      ((atom? state) state)
      (else (M_state (firstStatement statements) state
                     (lambda (s) (interpret_parsed (remaining statements) s))
                     baseBreak
                     baseContinue
                     baseThrow
                     baseReturn)))))


;;; breakdown ;;;
;;; breaks down a value (ie. true and false)
;; @value the value to break down
(define breakdown
  (lambda (value)
    (cond
      ((and (not (number? value)) value)       "true" )
      ((and (not (number? value)) (not value)) "false")
      (else value)
      )))

(define baseBreak (lambda (s) (error 'error "Break outside of block")))

(define baseContinue (lambda (s) (error 'error "Continue outside of block")))

(define baseThrow (lambda (v s) (error 'error "Throw outside of try block")))

(define baseReturn (lambda (v s) v))

(define remaining cdr)

(define firstStatement car)

;;;;;;;;;;;;;;;;; M_value functions ;;;;;;;;;;;;;;;;;;
(define M_value
  (lambda (expression state)
    (cond
      ((null? expression) '())
      ((number? expression) expression)
      ((eq? 'true expression) #t)
      ((eq? 'false expression) #f)
      ((atom? expression) (lookup expression state))

      ((member (operator expression) '(+ - * / %)) (M_value-arith expression state))
      ((member (operator expression) '(&& || ! < > <= >= == !=)) (M_value-boolean expression state)))))

(define M_value-arith
  (lambda (expression state)
    (cond
      ((eq? '+ (operator expression)) (+ (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
      ((eq? '- (operator expression)) (if (not (null? (cddr expression)))
                                            (- (M_value (operand1 expression) state) (M_value (operand2 expression) state))
                                            (- 0 (M_value (operand1 expression) state))))
      ((eq? '* (operator expression)) (* (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
      ((eq? '/ (operator expression)) (quotient (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
      ((eq? '% (operator expression)) (remainder (M_value (operand1 expression) state) (M_value (operand2 expression) state)))            
      (else (error 'unknown "unknown expression")))))

(define M_value-boolean
  (lambda (expression state)
      (cond
        ((eq? 'true expression) #t)
        ((eq? 'false expression) #f)
        ((eq? '&& (operator expression)) (and (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
        ((eq? '|| (operator expression)) (or (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
        ((eq? '! (operator expression)) (not (M_value (operand1 expression) state))) 
        ((eq? '< (operator expression)) (< (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
        ((eq? '> (operator expression)) (> (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
        ((eq? '<= (operator expression)) (<= (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
        ((eq? '>= (operator expression)) (>= (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
        ((eq? '== (operator expression)) (eq? (M_value (operand1 expression) state) (M_value (operand2 expression) state)))
        ((eq? '!= (operator expression)) (not (eq? (M_value (operand1 expression) state) (M_value (operand2 expression) state))))
        (else (error 'unknown "unknown expression")))))

(define operator car)

(define operand1 cadr)

(define operand2 caddr)

(define operand3 cadddr)

;M_value-return will take a return statement and return the statement right of "return"
(define M_value-return
  (lambda (expression state return)
    (return (convert_value (M_value (evaluatable expression) state)) state)))

(define evaluatable cadr)

; converts #t or #f to true and false respectively
(define convert_value
  (lambda (v)
    (cond
      ((null? v) '())
      ((eq? v #t) 'true)
      ((eq? v #f) 'false)
      (else v))))

;;;;;;;;;;;;;;;;;;;;;;; M_state section ;;;;;;;;;;;;;;;;;;
; lamnda (statement state return break continue throw)
(define M_state
  (lambda (statement state next break continue throw return)
    (cond
      ((null? (operation statement)) (error 'error "Empty statement."))
      
      ;; added for project 3 ;;
      ((eq? (operator statement) 'function) (M_state-functionDeclare statement state))
      ((eq? (operator statement) 'funcall) (M_state-functionCall statement state))
      
      ((eq? 'var (operation statement)) (M_state-declare statement state next))
      ((eq? '= (operation statement)) (M_state-assign statement state next break continue throw return))
      ((eq? 'try (operation statement)) (M_state-try statement state next break continue throw return))
      ((eq? 'begin (operation statement)) (M_state-begin statement state next break continue throw return))
      ((eq? 'throw (operation statement)) (M_state-throw statement state throw))
      ((eq? 'break (operation statement)) (M_state-break statement state break))
      ((eq? 'continue (operation statement)) (M_state-continue statement state continue))
      ((eq? 'return (operation statement)) (M_value-return statement state return))
      ((eq? 'if (operation statement)) (M_state-if statement state next break continue throw return))
      ((eq? 'while (operation statement)) (M_state-while statement state next break continue throw return))
      (else (error 'error "Unrecognized statement type.")))))

(define M_state-add-frame
  (lambda (state next)
    (next (cons (cons '() (variableList state)) (list (cons '() (valueList state)))))))

(define M_state-pop-frame
  (lambda (state next)
    (next (cons (restOfVariableFrames state) (list (restOfValueFrames state))))))

(define M_state-begin
  (lambda (statement state next break continue throw return)
    (cond
      ((not (eq? (car statement) 'begin)) (error 'error "Begin block without 'begin' at the beginning."))
      (else (M_state-add-frame state (lambda (st) (M_state-block (cdr statement) st
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (next s2))))
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (break s2))))
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (continue s2))))
                                                                 (lambda (v s) (M_state-pop-frame s (lambda (s2) (throw v s2))))
                                                                 (lambda (v s) (M_state-pop-frame s (lambda (s2) (return v s2)))))))))))

(define M_state-block
  (lambda (statements state next break continue throw return)
    (cond
      ((null? statements) (next state))
      (else (M_state (firstStatement statements) state
                     (lambda (s) (M_state-block (remaining statements) s next break continue throw return))
                     break continue throw return)))))

(define M_state-throw
  (lambda (statement state throw)
    (throw (M_value (throwVar statement) state) state)))

(define M_state-break
  (lambda (statement state break)
    (break state)))

(define M_state-continue
  (lambda (statement state continue)
    (continue state)))

(define throwVar cadr)

(define M_state-try
  (lambda (statement state next break continue throw return)
    (cond
      ((null? (finallyBlock statement))
        (M_state-add-frame state (lambda (st) (M_state-try-catch (tryBlock statement) (catchBlock statement) st
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (next s2))))
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (break s2))))
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (continue s2))))
                                                                 (lambda (v s) (M_state-pop-frame s (lambda (s2) (throw v s2))))
                                                                 (lambda (v s) (M_state-pop-frame s (lambda (s2) (return v s2))))))))
      ((null? (catchList statement))
       (M_state-add-frame state (lambda (st) (M_state-try-finally (tryBlock statement) (finallyStatements statement) st
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (next s2))))
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (break s2))))
                                                                 (lambda (s) (M_state-pop-frame s (lambda (s2) (continue s2))))
                                                                 (lambda (v s) (M_state-pop-frame s (lambda (s2) (throw v s2))))
                                                                 (lambda (v s) (M_state-pop-frame s (lambda (s2) (return v s2)))))))) 
      (else
        (M_state-add-frame state (lambda (st) (M_state-try-catch-finally
                                               (tryBlock statement) (catchBlock statement) (finallyStatements statement) st
                                               (lambda (s) (M_state-pop-frame s (lambda (s2) (next s2))))
                                               (lambda (s) (M_state-pop-frame s (lambda (s2) (break s2))))
                                               (lambda (s) (M_state-pop-frame s (lambda (s2) (continue s2))))
                                               (lambda (v s) (M_state-pop-frame s (lambda (s2) (throw v s2))))
                                               (lambda (v s) (M_state-pop-frame s (lambda (s2) (return v s2)))))))))))

(define catchList caddr)

(define tryBlock cadr)

(define catchBlock cdaddr)

(define finallyStatements
  (lambda (statement)
    (cadr (cadddr statement))))

(define finallyBlock cadddr)

(define M_state-try-catch
  (lambda (try catch state next break continue throw return)
    (M_state-block try state next break continue
                   (lambda (v s) (M_state-catch catch v s next break continue throw return)) return)))

(define M_state-catch
  (lambda (catch value state next break continue throw return)
    (cond
      ((null? value) (error 'error "Null value was thrown."))
      (else (M_state-pop-frame state
                               (lambda (st) (M_state-add-frame st
                                                               (lambda (s) (M_state-declare (buildDeclare (varName catch) value) s
                                                                                            (lambda (s2) (M_state-block (catchStatements catch) s2 next break continue throw return)))))))))))

(define catchStatements cadr)
      

(define buildDeclare
  (lambda (name value)
    (cons 'var (cons name (list value)))))

(define varName caar)

(define M_state-try-catch-finally
  (lambda (try catch finally state next break continue throw return)
    (M_state-block try state
                   (lambda (s) (finally-next-continuation finally s next break continue throw return))
                   (lambda (s) (finally-break-continuation finally s next break continue throw return))
                   (lambda (s) (finally-continue-continuation finally s next break continue throw return))
                   (lambda (v s) (finally-catch-throw-continuation catch v finally s next break continue throw return))
                   (lambda (v s) (finally-return-continuation finally s v next break continue throw return)))))

(define M_state-try-finally
  (lambda (try finally state next break continue throw return)
    (M_state-block try state
                   (lambda (s) (finally-next-continuation finally s next break continue throw return))
                   (lambda (s) (finally-break-continuation finally s next break continue throw return))
                   (lambda (s) (finally-continue-continuation finally s next break continue throw return))
                   (lambda (v s) (finally-throw-continuation finally s v next break continue throw return))
                   (lambda (v s) (finally-return-continuation finally s v next break continue throw return)))))

(define M_state-finally
  (lambda (statements state next break continue throw return)
    (M_state-pop-frame state
                       (lambda (st) (M_state-add-frame st
                                                       (lambda (s) (M_state-block statements s next break continue throw return)))))))

(define finally-next-continuation
  (lambda (finally state next break continue throw return)
    (M_state-finally finally state (lambda (s) (next s)) break continue throw return)))
               
(define finally-break-continuation
  (lambda (finally state next break continue throw return)
    (M_state-finally finally state (lambda (s) (break s)) break continue throw return)))

(define finally-continue-continuation
  (lambda (finally state next break continue throw return)
    (M_state-finally finally state (lambda (s) (continue s)) break continue throw return)))

(define finally-throw-continuation
  (lambda (finally state value next break continue throw return)
    (M_state-finally finally state (lambda (s) (throw value s)) break continue throw return)))

(define finally-catch-throw-continuation
  (lambda (catch value finally state next break continue throw return)
    (M_state-catch catch value state
                   (lambda (s) (finally-next-continuation finally s next break continue throw return))
                   (lambda (s) (finally-break-continuation finally s next break continue throw return))
                   (lambda (s) (finally-continue-continuation finally s next break continue throw return))
                   (lambda (v s) (M_state-finally finally s (lambda (s2) (throw v s2)) break continue throw return))
                   (lambda (v s) (finally-return-continuation finally s v next break continue throw return)))))

(define finally-return-continuation
  (lambda (finally state value next break continue throw return)
    (M_state-finally finally state (lambda (s) (return v s)) break continue throw return)))

(define M_state-while
  (lambda (statement state next break continue throw return)
    (if (M_value-boolean (GetCondition statement) state)
        (M_state (GetStatement statement) state
                 (lambda (s) (M_state-while statement s next break continue throw return))
                 (lambda (s) (next s))
                 (lambda (s) (M_state-while statement s next break continue throw return))
                 throw
                 return)
        (next state))))

(define GetStatement caddr)

(define M_state-if
  (lambda (statement state next break continue throw return)
    (cond
      ((M_value (GetCondition statement) state) (M_state (GetThenStatement statement) state next break continue throw return))
      ((not (null? (GetOptElse statement))) (M_state (GetOptElse statement) state next break continue throw return))
      (else (next state)))))

;Helper for if statement to get the first condition
(define GetCondition cadr)

;Helper for if statment to get the "then" statement
(define GetThenStatement caddr)

;Helper for if statement to get the optional else statement
(define GetOptElse
  (lambda (l)
    (if (null? (afterIfBlock l))
        '()
        (elseStatements l))))

(define afterIfBlock cdddr)

(define elseStatements cadddr)

;M_declare_statement will take a list starting with 'var followed by an atom with an optional value
(define M_state-declare
  (lambda (statement state next)
    (cond
      ; ((eq? 'function (operation statement)) (update
      ((not (eq? 'var (operation statement)) (error 'illegal "Declaration statment does not start with 'var'"))
      ((null? (declare-value-list statement)) (next (declare_var (declare-var-name statement) state)))
      (else (next (update_state (declare-var-name statement) (M_value (declare-val statement) state) (declare_var (declare-var-name statement) state) (lambda (v) v))))))))

(define declare-value-list cddr)

(define declare-val caddr)

(define declare-var-name cadr)

; M_assign takes a statement and state and updates the state with the desired variable assignment.
(define M_state-assign
  (lambda (statement state next break continue throw return)
    (cond
      ((not (eq? '= (operation statement))) (error 'illegal "Assignment statement does not start with '='"))
      (else (next (update_state (assign-var statement) (M_value (assign-expression statement) state) state (lambda (v) v)))))))

(define operation car)

(define assign-var cadr)

(define assign-expression caddr)


;;; project 3 ;;;

; M_state-functionDeclare takes a statement (eg. "main() {...}")
(define M_state-functionDeclare
  (lambda (statement state)
    (update_state_frame
     (operand1 statement)
     (cons (operand2 statement) (cons (operand3 statement) (cons (lambda() state) '())))
     (declare_var (operand1 statement) state)
     )))

; M_state-functionCall calls a function (eg. "mean(1, 2, 3)")
(define M_state-functionCall
  (lambda (statement state)
    (call/cc (lambda (return)
      (interpret_function
       (cadr (lookup (operand1 statement) state))
       (set_formal_parameters
        (cddr statement)
        (car (lookup (operand1 statement) state))
        state
        ((caddr (lookup (operand1 statement) state))))
       return)
))))


(define interpret_function (lambda (statement state return)
    (popStack
      (interpret_statement_list
        statement
        (pushStack state)
        return
        (lambda (v) (error "Illegal break"))
        (lambda (v) (error "Illegal continue")))
        )))


;;;;;;;;;;;;;;; State manipulation and management ;;;;;;;;;;;;;;;;;;;;;;;
(define lookup
  (lambda (name state)
    (cond
      ((null? state) 'undefined)
      ((empty?  (variables state)) (error 'error "Using variable before it is assigned."))
      ((empty?  (firstVariableFrame state)) (lookup name (cons (remaining_variables state) (list (remaining_values state)))))
      ((and (eq? name (first_variable state)) (eq? 'undefined (first_value state))) (error 'error "Using variable before it is assigned."))
      ((and (eq? name (first_variable state)) (atom? (first_value state))) (first_value state))
      ;abstract this shit
      ((eq? name (first_variable state)) (caadr state))
      (else (lookup name (cons (cons (rest_of_first_varframe state) (restOfVariableFrames state)) (list (cons (rest_of_first_valframe state) (restOfValueFrames state)))))))))

(define variables car)

(define first_variable caaar)

(define remaining_variables cdar)

(define state_values cadr)

(define first_value caaadr)

(define remaining_values cdadr)

(define rest_of_first_varframe cdaar)

(define rest_of_first_valframe cdaadr)

(define atom?
  (lambda (expression)
    (not (or (pair? expression) (null? expression)))))

; declare_var adds a new variable to the state with 'undefined as its initial value
(define declare_var
  (lambda (name state)
    (cond
      ((null? state) 'undefined)
      ((contains? name (variableList state)) (error 'error "Duplicate delcaration of variable."))
      (else (cons (cons (cons name (firstVariableFrame state)) (restOfVariableFrames state)) (list (cons (cons 'undefined (firstValueFrame state)) (restOfValueFrames state))))))))

(define contains?
  (lambda (v l)
    (cond
      ((null? l) #f)
      ((eq? v (frontOfList l)) #t)
      ((list? (frontOfList l)) (or (contains? v (frontOfList l)) (contains? v (restOfList l))))
      (else (contains? v (restOfList l))))))

(define frontOfList car)

(define restOfList cdr)

(define variableList car)

(define valueList cadr)

(define firstVariableFrame caar)

(define restOfVariableFrames cdar)

(define firstValueFrame caadr)

(define restOfValueFrames cdadr)

; update_state takes a name and a value and updates that name with the value if it exists in the state
(define update_state_frame
  (lambda (name value state)
    (cond
      ((null? state) 'undefined)
      ((null? (variableList state)) (print state))
      ((eq? name (caaar state)) (cons (variables state) (list (cons value (remaining_values state)))))
      (else ((lambda (newState)
               (cons (cons (caar state) (variables newState)) (list (cons (caadr state) (state_values newState)))))
             (update_state_frame name value (cons (remaining_variables state) (list (remaining_values state)))))))))

(define update_state
  (lambda (name value state return)
    (cond
      ((null? state) (error 'undefined "Attempting to assign an undeclared variable."))
      ((null? (variableList state)) (error 'undefined "Attempting to assign an undeclared variable."))
      ((contains? name (firstVariableFrame state)) (return (cons (variableList state)
                                                           (list (cons (valueList (update_state_frame name value (firstFrameState state))) (restOfValueFrames state))))))
      (else (update_state name value (cons (restOfVariableFrames state) (list (restOfValueFrames state))) (lambda (s) (return (cons (cons (firstVariableFrame state) (variableList s)) (list (cons (firstValueFrame state) (valueList s)))))))))))

(define firstFrameState
  (lambda (state)
    (cons (firstVariableFrame state) (list (firstValueFrame state)))))


; sets the formal parameters of the environment to the values in the given parameters.
(define set_formal_parameters
  (lambda (parameters formals state functionState)
    (cond
      ((and (null? parameters) (null? formals))
       state)
      ((or  (null? parameters) (null? formals))
       (error "Invalid number of arguments"))
      ((or (null? (cdr parameters)) (null? (cdr formals)))
       (assign
        (car formals)
        (M_value (car parameters) state)
        (declare (car formals) funcenv)))
      (else (assign
        (car formals)
        (M_value (car parameters) state)
        (declare
          (car formals)
          (set_formal_parameters
            (cdr parameters)
            (cdr formals)
            env
            functionState))))
      )))


(parser "test/test1")
(interpret "test/test1")