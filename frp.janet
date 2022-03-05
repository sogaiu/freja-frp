(import freja-jaylib :as fj)

(import ./events :as e)
(import ./state :as state)
(import ./keyboard :as kb)
(import ./vector-math :as v)

###########################################################################

(varfn i/new-mouse-data
  []
  @{:just-down nil
    :just-double-clicked nil
    :just-triple-clicked nil
    :recently-double-clicked nil
    :recently-triple-clicked nil
    :down-pos nil
    :down-time nil
    :down-time2 nil
    :up-pos nil
    :selected-pos nil
    :last-text-pos nil})

## delay before first repetition of held keys
# TODO: if these delays are set to super low, frp bugs and wont release keys
(var i/initial-delay 0.2)

## delay of each repetition thereafter
(var i/repeat-delay 0.03)

###########################################################################

(var mouse nil)
(var chars nil)
(var keyboard nil)
(var frame-chan nil)
(var rerender nil)
(var out nil)
(var screen-size @{})

(var delay-left @{})

(defn handle-keys
  [dt]
  (var k (fj/get-char-pressed))
  #
  (while (not= 0 k)
    (e/push! chars @[:char k])
    (set k (fj/get-char-pressed)))
  # must release keys before...
  (loop [k :in kb/possible-keys]
    (when (fj/key-released? k)
      (e/push! keyboard @[:key-release k])))
  # ...checking for held keys
  (loop [[k dl] :pairs state/keys-down
         # might just have been released
         :when (not (fj/key-released? k))
         :let [left ((update state/keys-down k - dt) k)]]
    (when (<= left 0)
      (e/push! keyboard @[:key-repeat k])))
  #
  (loop [k :in kb/possible-keys]
    (when (fj/key-pressed? k)
      (e/push! keyboard @[:key-down k]))))

(varfn handle-scroll
  []
  (let [move (fj/get-mouse-wheel-move)]
    (when (not= move 0)
      (e/push! mouse
               @[:scroll (* move 30) (fj/get-mouse-position)]))))

# table of callbacks, e.g.
#
#   @{@[:down [10 10]]         [|(print "hello") |(print "other")]}
#
#     ^ a mouse event          ^ queued callbacks
#     ^ is actually a ev/chan
#     ^ but using an array here to visualise
(def callbacks
  @{:event/changed false})

(varfn handle-resize
  []
  (when (fj/window-resized?)
    (-> screen-size
        (e/put! :screen/width (fj/get-screen-width))
        (e/put! :screen/height (fj/get-screen-height)))))

(defn push-callback!
  [ev cb]
  (e/update! callbacks ev (fn [chan]
                            (default chan (ev/chan 1))
                            (e/push! chan cb)
                            chan)))

(defn handle-callbacks
  [callbacks]
  (loop [[ev cbs] :pairs callbacks
         :when (not= ev :event/changed)]
    (e/pull-all cbs [apply]))
  #
  (loop [k :in (keys callbacks)]
    (put callbacks k nil)))

(def mouse-data
  (i/new-mouse-data))

(varfn handle-mouse
  [mouse-data]
  (def pos (fj/get-mouse-position))
  (def [x y] pos)
  #
  (put mouse-data :just-double-clicked false)
  (put mouse-data :just-triple-clicked false)
  #
  (when (fj/mouse-button-released? 0)
    (put mouse-data :just-down nil)
    (put mouse-data :recently-double-clicked nil)
    (put mouse-data :recently-triple-clicked nil)
    (put mouse-data :up-pos [x y])
    #
    (e/push! mouse @[:release (fj/get-mouse-position)]))
  #
  (when (fj/mouse-button-pressed? 0)
    (when (and (mouse-data :down-time2)
               # max time to pass for triple click
               (> 0.4 (- (fj/get-time) (mouse-data :down-time2)))
               # max distance to travel for triple click
               (> 200 (v/dist-sqr pos (mouse-data :down-pos))))
      (put mouse-data :just-triple-clicked true)
      (put mouse-data :recently-triple-clicked true))
    #
    (when (and (mouse-data :down-time)
               # max time to pass for double click
               (> 0.25 (- (fj/get-time) (mouse-data :down-time)))
               # max distance to travel for double click
               (> 100 (v/dist-sqr pos (mouse-data :down-pos))))
      (put mouse-data :just-double-clicked true)
      (put mouse-data :recently-double-clicked true)
      (put mouse-data :down-time2 (fj/get-time))))
  #
  (cond
    (mouse-data :just-triple-clicked)
    (e/push! mouse @[:triple-click (fj/get-mouse-position)])
    #
    (and (mouse-data :just-double-clicked)
         (not (fj/key-down? :left-shift))
         (not (fj/key-down? :right-shift)))
    (e/push! mouse @[:double-click (fj/get-mouse-position)])
    #
    (or (mouse-data :recently-double-clicked)
        (mouse-data :recently-triple-clicked))
    nil # don't start selecting until mouse is released again
    #
    (fj/mouse-button-down? 0)
    (do
      (put mouse-data :down-time (fj/get-time))
      #
      (if (= nil (mouse-data :just-down))
        (do (put mouse-data :just-down true)
          (put mouse-data :last-pos pos)
          (put mouse-data :down-pos pos)
          (e/push! mouse @[:press (fj/get-mouse-position)]))
        (do (put mouse-data :just-down false)
          (unless (= pos (mouse-data :last-pos))
            (put mouse-data :last-pos pos)
            (e/push! mouse @[:drag (fj/get-mouse-position)])))))
    # no mouse button down
    (not= pos (mouse-data :last-pos))
    (do (put mouse-data :last-pos pos)
      (e/push! mouse @[:mouse-move (fj/get-mouse-position)]))))

(def deps @{})

(varfn render-deps
  [dt]
  (loop [d :in (deps :draws)]
    (d)))

(def finally
  @{frame-chan [render-deps]})

(defn handle-key-events
  [ev]
  (match ev
    [:key-release k]
    (put state/keys-down k nil)
    #
    [:key-repeat k]
    (put state/keys-down k i/repeat-delay)
    #
    [:key-down k]
    (put state/keys-down k i/initial-delay)))

(varfn init-chans
  []
  (print "initing chans")
  (set mouse (ev/chan 100))
  (set chars (ev/chan 100))
  (set keyboard (ev/chan 100))
  (set frame-chan (ev/chan 1))
  (set rerender (ev/chan 1))
  (set out (ev/chan 100))
  (set state/eval-results (ev/chan 100))
  #
  (def dependencies
    @{mouse @[]
      keyboard @[handle-key-events |(:on-event (state/focus :focus) $)]
      chars @[|(:on-event (state/focus :focus) $)]
      state/focus @[]
      callbacks @[handle-callbacks]
      out @[|(with-dyns [:out stdout]
               (print $))]})
  #
  (def draws @[])
  #
  (merge-into deps @{:deps dependencies
                     :draws draws
                     :finally finally}))

(varfn trigger
  [dt]
  (handle-keys dt)
  (handle-scroll)
  (handle-resize)
  #
  (e/push! frame-chan @[:dt dt])
  #
  (handle-mouse mouse-data)
  #
  (comment
    (when (fj/mouse-button-pressed? 0)
      # uses arrays in order to have reference identity rather than
      # value identity
      # relevant for callback handling
      (e/push! mouse @[:press (fj/get-mouse-position)])))
  #
  (e/pull-deps (deps :deps) (deps :finally)))

(defn subscribe-first!
  ``
  Take an event emitter (e.g. a ev/channel) and a callback (e.g.
  single arity function).

  Creates a subscription that sits before any existing ones.
  ``
  [emitter cb]
  (unless (find |(= $ cb) (get-in deps [:deps emitter] []))
    (update-in deps [:deps emitter] (fn [$] @[cb ;(or $ [])]))))

(defn subscribe!
  ``
  Take an event emitter (e.g. a ev/channel) and a callback (e.g.
  single arity function).

  Creates a regular subscription.
  ``
  [emitter cb]
  (unless (find |(= $ cb) (get-in deps [:deps emitter] []))
    (update-in deps [:deps emitter] |(array/push (or $ @[]) cb))
    :ok))

(defn unsubscribe!
  ``
  Take an event emitter (e.g. a ev/channel) and a callback (e.g.
  single arity function).

  Removes a regular subscription.
  ``
  [emitter cb]
  (update-in deps [:deps emitter]
             (fn [subs] (filter |(not= $ cb) subs)))
  :ok)

(defn subscribe-finally!
  ``
  Take an event emitter (e.g. a ev/channel) and a callback (e.g.
  single arity function).

  Creates a finally subscription.
  ``
  [emitter cb]
  (unless (find |(= $ cb) (get-in deps [:finally emitter] []))
    (update-in deps [:finally emitter] |(array/push (or $ @[]) cb))
    :ok))

(defn unsubscribe-finally!
  ``
  Take an event emitter (e.g. a ev/channel) and a callback (e.g.
  single arity function).

  Removes a finally subscription.
  ``
  [emitter cb]
  (update-in deps [:finally emitter]
             (fn [subs] (filter |(not= $ cb) subs)))
  :ok)

