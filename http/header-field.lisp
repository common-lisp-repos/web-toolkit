(in-package :http)

(defgeneric header-field-name (header-field))

(defgeneric (setf header-field-name) (name header-field))

(defgeneric header-field-value (header-field))

(defgeneric (setf header-field-value) (value header-field))

(defgeneric header-field-name-match-p (header-field name))

(defclass header-field ()
  ((name
    :initarg :name
    :initform nil
    :reader header-field-name)
   (value
    :initarg :value
    :initform nil
    :reader header-field-value)))

(defmethod print-object ((header-field header-field) stream)
  (print-unreadable-object (header-field stream :type t)
    (format stream "~A: ~A"
            (header-field-name header-field)
            (header-field-value header-field))))

(defmethod initialize-instance :after ((header-field header-field) &key)
  (setf (header-field-name header-field) (slot-value header-field 'name)
        (header-field-value header-field) (slot-value header-field 'value)))

(defmethod (setf header-field-name) (name header-field)
  (let ((name (typecase name
                (string name)
                (t (header-case (format nil "~A" name))))))
    (setf (slot-value header-field 'name) name)))

(defmethod header-field-name ((header-field null))
  nil)

(defmethod (setf header-field-value) (value header-field)
  (let ((value (typecase value
                 (string value)
                 (t (format nil "~A" value)))))
    (setf (slot-value header-field 'value) value)))

(defmethod header-field-value ((header-field null))
  nil)

(defmethod header-field-name-match-p (header-field name)
  (let ((name (typecase name
                (string name)
                (t (format nil "~A" name)))))
    (string-equal name (header-field-name header-field))))

(defmacro header-field (name value)
  `(make-instance 'header-field :name ,name :value ,value))
