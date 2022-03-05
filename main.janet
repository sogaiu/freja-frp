(import freja-jaylib :as fj)

(import ./frp)

(defn main
  [& args]
  (frp/init-chans)
  #
  (fj/set-config-flags :window-resizable)
  #
  (fj/init-window 800 600 "frp")
  # XXX: tweak these for fun -- see frp.janet for more
  (frp/subscribe! frp/mouse pp)
  (frp/subscribe! frp/keyboard pp)
  #
  (while true
    (try
      (do
        (def dt (fj/get-frame-time))
        (fj/begin-drawing)
        (fj/clear-background :black)
        (frp/trigger dt)
        (fj/end-drawing))
      ([err fib]
        (print (debug/stacktrace fib err ""))
        (ev/sleep 1)))))

