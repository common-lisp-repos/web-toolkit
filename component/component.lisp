(in-package :component)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass component-class (standard-class)
    (;; CCL require this slot to exists
     (tag
      :initarg :tag
      :initform nil)
     (render
      :initarg :render
      :initform nil)
     (%render
      :initform nil
      :accessor component-render)
     (render-lambda-list
      :initarg :render-lambda-list
      :initform nil
      :accessor component-render-lambda-list))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmethod validate-superclass
      ((class component-class) (super-class standard-class)) t))

(defmethod shared-initialize :after ((class component-class) slot-names
                                     &key render &allow-other-keys)
  (declare (ignore slot-names))
  (if render
      (let ((lambda-form (car render)))
        (setf render (make-render lambda-form))
        ;; TODO: check render
        ;; (check-render render)
        (let ((render-lambda-list (function-lambda-list render)))
          (setf (slot-value class '%render) render)
          (setf (slot-value class 'render-lambda-list) render-lambda-list)))
      (progn (setf (slot-value class '%render) nil
                   (slot-value class 'render-lambda-list) nil))))

(defclass component (html:custom-element)
  ((tag
    :initarg :tag
    :initform nil
    :accessor component-tag)
   (root
    :initarg :root
    :initform nil
    :accessor component-root)
   (children
    :initarg :children
    :initform nil
    :accessor component-children))
  (:metaclass component-class))

(defmethod initialize-instance :after ((component component) &key)
  (unless (component-tag component)
    (error "Tag for component ~A is not specified" component)))

(defmethod component-render ((component component))
  (component-render (class-of component)))

(defmethod component-render-lambda-list ((component component))
  (component-render-lambda-list (class-of component)))

(defgeneric compute-component-class (component)
  (:method ((component component))
    (flet ((class-name-for-component-class (class)
             (format nil "~(~A~)-~(~A~)"
                     (package-name (symbol-package (cl:class-name class)))
                     (symbol-name (cl:class-name class)))))
      (let ((classes (compute-class-precedence-list (class-of component))))
        (loop for class in classes
           until (eq class (find-class 'component))
           collect (class-name-for-component-class class)
           into classes
           finally (return (reverse classes)))))))

(defmethod html:root ((component component))
  (component-root component))

(defmethod root ((component component))
  (component-root component))

(defmethod children ((component component))
  (component-children component))

(defmethod serialize ((component component) &optional stream)
  (serialize (render component) stream))

(defclass constructor ()
  ((component-class
    :initarg :component-class
    :initform nil
    :reader constructor-component-class)))

(defgeneric construct (constructor &rest arguments)
  (:method ((constructor constructor) &rest arguments)
    (multiple-value-bind (attributes children)
        (segment-attributes-children arguments)
      (let* ((slot-initargs (flatten
                             (mapcar 'slot-definition-initargs
                                     (class-slots
                                      (find-class
                                       (constructor-component-class constructor))))))
             (slot-attributes '())
             (root-attributes '()))
        (loop for (name value) on attributes by #'cddr
           if (find (symbol-name name) slot-initargs :key 'symbol-name :test 'equal)
           do (appendf slot-attributes `(,name ,value))
           else do (appendf root-attributes `((,name . ,value))))
        (loop for (_name . _value) in root-attributes
           for name = (string-downcase (symbol-name _name))
           for value = (if (eq _value t)
                           ""
                           (typecase _value
                             (null nil)
                             (string _value)
                             (list (format nil "~{~A~^ ~}" _value))
                             (t (format nil "~A" _value))))
           when value
           collect `(,name . ,value) into attributes
           finally (setf root-attributes attributes))
        (let ((component (apply 'make-instance
                                (constructor-component-class constructor)
                                :attributes root-attributes
                                :children children
                                slot-attributes)))
          ;; (let ((class (compute-component-class component)))
          ;;   (setf (component-class component) class))
          (render component)
          component)))))

(defmacro define-component (name superclasses slots &rest options)
  `(progn
     (eval-when (:compile-toplevel :load-toplevel :execute)
       (define-component-class ,name ,superclasses ,slots ,@options)
       (define-component-constructor ,name))))

(defmacro define-component-class (name superclasses slots &rest options)
  (unless (find 'component superclasses)
    (appendf superclasses '(component)))
  (unless (find :metaclass options :key 'first)
    (rewrite-class-option options :metaclass component-class))
  (let ((tag-option (find :tag options :key 'first)))
    (unless tag-option
      (error "Missing tag option when defining component ~A" name))
    (let ((default-tag (second tag-option)))
      ;; TODO: refine this
      (appendf slots
               `((tag :initform ,default-tag)))))
  `(progn
     (defclass ,name ,superclasses
       ,slots
       ,@options)
     (ensure-finalized (find-class ',name))))

(defmacro define-component-constructor (component-name)
  (let* ((constructor-name (format nil "~A-CONSTRUCTOR" component-name))
         (constructor-symbol (intern constructor-name)))
    `(eval-when (:compile-toplevel :load-toplevel :execute)
       (defclass ,constructor-symbol (constructor)
         ((component-class :initform ',component-name)))
       ;; (defvar ,component-name (make-instance ',constructor-symbol))
       (defun ,component-name (&rest arguments)
         (let ((constructor (make-instance ',constructor-symbol)))
           (apply 'construct constructor arguments))))))

(defun make-component-root (component &rest arguments)
  (let ((tag (component-tag component)))
    (let ((constructor (html:constructor tag)))
      (let ((root (html:construct constructor)))
        (loop for (name . value) in (dom::attributes component)
           do (dom:set-attribute root name value))
        (multiple-value-bind (attributes children)
            (segment-attributes-children arguments)
          (loop for (name value) on attributes by #'cddr
             do (dom:set-attribute root name value))
          (setf (slot-value root 'style)
                (style:merge-style (slot-value component 'style) (slot-value root 'style)))
          (loop for child in (flatten children)
             do (typecase child
                  (string (dom:append-child root (html:text child)))
                  (html:element (dom:append-child root child))
                  (style (setf (slot-value root 'style)
                               (style:merge-style (slot-value root 'style) child))))))
        (let ((classes (compute-component-class component))
              (class (dom:get-attribute root "class")))
          (when (and class (not (find class classes :test 'equal)))
            (appendf classes (list class)))
          (dom:set-attribute root "class" (format nil "~{~A~^ ~}" classes)))
        (setf (component-root component) root)))))

(defgeneric render (component)
  (:method ((component component))
    (if-let ((render (component-render component)))
      (let ((lambda-list (component-render-lambda-list component)))
        (cond
          ((= 0 (length lambda-list)) (funcall render))
          ((= 1 (length lambda-list)) (funcall render component))))
      (funcall (make-render '(lambda (c) (declare (ignore c)) root)) component))))

(defgeneric copy-element (element)
  (:method ((list list))
    (mapcar 'copy-element list))
  (:method ((element html:element))
    (let ((class (class-of element)))
      (let ((new-element (allocate-instance class)))
        (dolist (slot (mapcar #'slot-definition-name (class-slots class)))
          (when (slot-boundp element slot)
            (setf (slot-value new-element slot)
                  (slot-value element slot))))
        (setf (dom:children new-element) (copy-element (dom:children element)))
        new-element)))
  (:method ((text html:text))
    (let ((data (dom:data text)))
      (make-instance 'html:text :data data))))

(defun make-render (lambda-form)
  (unless (eq 'lambda (car lambda-form))
    (error "Expect a LAMBDA form for render, got ~A" lambda-form))
  (let ((lambda-list (cadr lambda-form)))
    (unless (listp lambda-list)
      (error "Expect a LAMBDA form for render, got ~A" lambda-form))
    (let ((component (car lambda-list)))
      (unless component
        (error "Malformed LAMBDA-LIST for render, got ~A" lambda-list))
      (let ((body (cddr lambda-form)))
        (let ((render-lambda-form
               `(lambda ,lambda-list
                  (make-component-root ,component)
                  (setf (component-children ,component)
                        (copy-element (component-children ,component)))
                  (macrolet ((root (&rest arguments)
                               (let ((component ',component))
                                 `(make-component-root
                                   ,component
                                   ,@arguments))))
                    (symbol-macrolet ((root (component-root ,component))
                                      (children (component-children ,component)))
                      ,@body)))))
          (values (eval render-lambda-form) render-lambda-form))))))

;; (pprint (nth-value 1 (make-render '(lambda (compoment) (root)))))

;; (funcall (make-render '(lambda (component) (root))) (foo))

;; (define-component foo ()
;;   ()
;;   (:tag :div))

;; (define-component bar (foo)
;;   ()
;;   (:tag :div))
