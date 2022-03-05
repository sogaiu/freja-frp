# XXX: this shadows a janet built-in
(var quit false)

(var gb-binds nil)

(var quit-hook nil)

(def freja-dir @"")

(var initial-file nil)

(def open-files @{})

(var eval-results nil)

(def focus @{})

(def keys-down @{})

(def out @"")

(def err @"")

(def editor-state @{})

(var user-env (make-env))

(def editor-components @{})

(def editor-state-creators @{})

(defn ext->editor
  [ext &opt data]
  (default ext
    (do
      (print "no ext provided, defaulting to .janet")
      ".janet"))
  (def compo (get editor-components ext))
  (default compo
    (do
      (printf "no component found for %s, defaulting to .janet" ext)
      (editor-components ".janet")))
  (def state-creator (get editor-state-creators ext))
  (default state-creator
    (do
      (printf "no state-creator found for %s, defaulting to .janet" ext)
      (editor-state-creators ".janet")))
  #
  [(compo data) (state-creator data)])

(defn add-ext-handling
  [ext component creator]
  (put editor-components ext component)
  (put editor-state-creators ext creator))

(defn push-buffer-stack
  [o]
  (def new-stack
    (-> (filter |(not= o $) (editor-state :stack))
        (array/push o)))
  (-> editor-state
      (put :stack new-stack)
      (put :event/changed true)))

(defn remove-buffer-stack
  [o]
  (def new-stack
    (filter |(not= o $) (editor-state :stack)))
  (-> editor-state
      (put :stack new-stack)
      (put :event/changed true)))

(defn focus!
  ``
  Sets global focus to x.
  ``
  [x]
  (-> focus
      (put :last-focus (focus :focus))
      (put :focus x)
      (put :event/changed true)))

