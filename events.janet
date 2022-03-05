# a push-pull system
# events are pushed to queues
# then things can pull from the queues

(import ./state)

# functions to not block the fiber when interacting with channels
(defn pop
  ``
  Like `ev/take` but non-blocking, instead returns `nil` if the
  channel is empty.
  ``
  [chan]
  (when (pos? (ev/count chan))
    (ev/take chan)))

(defn push!
  ``
  Like `ev/give`, but if the channel is full, throw away the
  oldest value.
  ``
  [chan v]
  (when (ev/full chan)
    (ev/take chan)) ## throw away old values
  (ev/give chan v))

(defn vs
  ``
  Returns the values in a channel.
  ``
  [chan]
  (def vs @[])
  # empty the queue
  (loop [v :iterate (pop chan)]
    (array/push vs v))
  # then put them back again
  (loop [v :in vs]
    (push! chan v))
  #
  vs)

# we want to be able to pull
# multiple things should be able to pull from it
# essentially splitting the value

(defn pull
  [pullable pullers]
  (when-let [v (case (type pullable)
                 :core/channel
                 (pop pullable)
                 #
                 :table
                 (when (pullable :event/changed)
                   (put pullable :event/changed false))
                 #
                 (errorf "%s is not a pullable." (type pullable)))]
    (loop [puller :in pullers]
      (try
        (case (type puller)
          :function
          (puller v)
          #
          :core/channel
          (push! puller v)
          #
          :table
          (:on-event puller v)
          #
          (errorf "Pulling not implemented for %s" (type puller)))
        ([err fib]
          (push! state/eval-results
                 (if (and (dictionary? err) (err :error))
                   err
                   (let [event
                         (if (dictionary? v)
                           (string/format "dictionary with keys: %p"
                                          (keys v))
                           v)
                         subscriber
                         (if (dictionary? puller)
                           (string/format "dictionary with keys: %p"
                                          (keys puller))
                           puller)]
                     {:error err
                      :fiber fib
                      :msg (string/format
                             ``
                             %s
                             event:
                             %p
                             subscriber:
                             %p
                             ``
                             err event subscriber)
                      :cause [v puller]}))))))
    # if there was a value, we return it
    v))

(defn pull-all
  [pullable pullers]
  (while
    (pull pullable pullers)
    nil))

(defn put!
  [state k v]
  (-> state
      (put k v)
      (put :event/changed true)))

(defn update!
  [state k f & args]
  (-> state
      (update k f ;args)
      (put :event/changed true)))

(defn record-all
  [pullables]
  (loop [[pullable pullers] :pairs pullables]
    (case (type pullable)
      :core/channel
      (array/push pullers
                  @{:history (ev/chan 10000)
                    :on-event (fn [self ev]
                                (update self :history push! ev))})
      #
      :table
      (array/push pullers
                  @{:history (freeze pullable)
                    :on-event (fn [self ev] nil)})))
  pullables)

(defn fresh?
  [pullable]
  (case (type pullable)
    :core/channel
    (pos? (ev/count pullable))
    #
    :table
    (pullable :event/changed)))

(varfn pull-deps
  [deps &opt finally]
  # as long as dependencies have changed (are `fresh?`)
  # keep looping through them and tell dependees
  # that changes have happened (`pull-all`)
  (while (some fresh? (keys deps))
    (loop [[pullable pullers] :pairs deps]
      (pull-all pullable pullers)))
  # then when all is done, run the things in `finally`
  (loop [[pullable pullers] :pairs (or finally {})]
    (pull-all pullable pullers)))
