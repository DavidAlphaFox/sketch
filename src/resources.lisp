;;;; resources.lisp

(in-package #:sketch)

;;;  ____  _____ ____   ___  _   _ ____   ____ _____ ____
;;; |  _ \| ____/ ___| / _ \| | | |  _ \ / ___| ____/ ___|
;;; | |_) |  _| \___ \| | | | | | | |_) | |   |  _| \___ \
;;; |  _ <| |___ ___) | |_| | |_| |  _ <| |___| |___ ___) |
;;; |_| \_\_____|____/ \___/ \___/|_| \_\\____|_____|____/

;;; Classes

(defclass resource () ())

(defclass image (resource)
  ((texture :accessor image-texture :initarg :texture)
   (sampler :accessor image-sampler :initarg :sampler)
   (width :accessor image-width :initarg :width)
   (height :accessor image-height :initarg :height)))

(defclass typeface (resource)
  ((filename :accessor typeface-filename :initarg :filename)
   (pointer :accessor typeface-pointer :initarg :pointer)))

;;; Loading

(defun file-name-extension (name)
  ;; taken from dto's xelf code
  (let ((pos (position #\. name :from-end t)))
    (when (numberp pos)
      (subseq name (1+ pos)))))

(defun load-resource (filename &rest all-keys &key type force-reload-p &allow-other-keys)
  (let ((*env* (or *env* (make-env)))) ;; try faking env if we still don't have one
    (symbol-macrolet ((resource (gethash key (env-resources *env*))))
      (let* ((key (alexandria:make-keyword
                   (alexandria:symbolicate filename (format nil "~a" all-keys)))))
        (when force-reload-p
          (free-resource resource)
          (remhash key (env-resources *env*)))
        (when (not resource)
          (setf resource
                (apply #'load-typed-resource
                       (list*  filename
                               (or type
                                   (case (alexandria:make-keyword
                                          (alexandria:symbolicate
                                           (string-upcase (file-name-extension filename))))
                                     ((:png :jpg :jpeg :tga :gif :bmp) :image)
                                     ((:ttf :otf) :typeface)))
                               all-keys))))
        resource))))

(defgeneric load-typed-resource (filename type &key &allow-other-keys))

(defmethod load-typed-resource (filename type &key &allow-other-keys)
  (if (not type)
      (error (format nil "~a's type cannot be deduced." filename))
      (error (format nil "Unsupported resource type ~a" type))))

(defun make-image-from-surface (surface)
  (let ((width (sdl2:surface-width surface))
        (height (sdl2:surface-height surface)))
    (let* ((texture (prog1 (let ((carr (make-c-array-from-pointer
                                        (list width height)
                                        :uint8-vec4
                                        (sdl2:surface-pixels surface))))
                             (make-texture carr))
                      (sdl2:free-surface surface)))
           (sampler (sample texture)))
      (make-instance 'image :width width :height height :texture texture
                     :sampler sampler))))

(defmethod load-typed-resource (filename (type (eql :image)) &key &allow-other-keys)
  (make-image-from-surface (sdl2-image:load-image filename)))

(defmethod load-typed-resource (filename (type (eql :typeface))
                                &key (size 18) &allow-other-keys)
  (make-instance 'typeface
                 :filename filename
                 :pointer (sdl2-ttf:open-font filename
                                              (coerce (truncate size)
                                                      '(signed-byte 32)))))

(defgeneric free-resource (resource))

(defmethod free-resource :around (resource)
  (when resource
    (call-next-method)))

(defmethod free-resource ((image image))
  (free (image-texture image)))

(defmethod free-resource ((typeface typeface)))
