
;   Muvee Custom Style by SoftSteph ;) -  V10
;   For Audio Clips Usage with Scan Line Effect
;   Shake Effect Selector


;-----------------------------------------------------------
;   Style parameters

(style-parameters
  (continuous-slider	AVERAGE_SPEED	0.75	0.0  1.0)
  (continuous-slider	MUSIC_RESPONSE	0.75	0.0  1.0)
  (switch		TV_SCAN_LINES	on)
  (switch		EXPLODE	on)
  (continuous-slider	SATURATION	1.0	0.0  2.0)
  (one-of-many		COLOR_EFFECT	None	(None Sepia SunsetGlow BlueShift GreenShift RedShift YellowTint GreenFire Charcoal CoolCyan PurpleHaze AquaBlue Mauve SandyBrown))
  (continuous-slider	COLOR_STRENGTH	0.5	0.0  1.0))


;-----------------------------------------------------------
;   Music pacing Definition
;   - segment/transition durations and playback speed
;   - transfer curves subdomain mapping

(let ((tc-mid (+ (* AVERAGE_SPEED 0.5) 0.25))
      (MUSIC_RESPONSE 0.5)
      (tc-dev (* MUSIC_RESPONSE 0.25))))
      
  ;(map-tc-subdomain (- tc-mid tc-dev) (+ tc-mid tc-dev))

  

(segment-durations 5.0 5.0 7.0 4.0 7.0 4.0)

(segment-duration-tc            0.00  1.00
       0.05  0.30
       0.10  0.50
       0.15  1.00
       0.20  0.30
       0.25  0.50
       0.30  1.00
       0.35  0.30
       0.40  0.50
       0.45  1.00
       0.50  0.30
       0.55  0.50
       0.60  1.00
       0.65  0.30
       0.70  0.50
       0.75  1.00
       0.80  0.30
       0.85  0.50
       0.90  1.00
       0.95  0.30
       1.00  0.50)      
      
(time-warp-tc       0.00  0.30
     0.05  1.00
     0.10  0.70
     0.15  0.30
     0.20  1.00
     0.25  0.70
     0.30  0.30
     0.35  1.00
     0.40  0.70
     0.45  0.30
     0.50  1.00
                          0.55  0.70
     0.60  0.30
     0.65  1.00
     0.70  0.70
     0.75  0.30
     0.80  1.00
     0.85  0.70
     0.90  0.30
     0.95  1.00
     1.00  0.70)
     
(min-segment-duration-for-transition 0.7)

(preferred-transition-duration 1.0)

(transition-duration-tc              0.00  16.00
          0.05  0
          0.10  4.00
          0.15  0
          0.20  1.00
          0.25  16.00
          0.30  0
          0.35  4.00
          0.40  0
          0.45  1.00
          0.50  16.00
          0.55  0
          0.60  4.00
          0.65  0
          0.70  1.00
          0.75  16.00
          0.80  0
          0.85  4.00
          0.90  0
          0.95  1.00
          1.00  16.00)


		  
;-----------------------------------------------------------
;   Global effects Definition
;   - television scan lines overlay

;;; scan lines ;;;

(define image-overlay-fx
  (fn (file opacity)
    (layers (A)
      A
      (effect-stack
        (effect "Translate" (A)
                (param "z" 0.003))
        (effect "Alpha" (A)
                (param "Alpha" opacity))
        (effect "PictureQuad" ()
                (param "Path" (resource file)))))))

(define scanlines-fx
  (if (= TV_SCAN_LINES 'on)
    (image-overlay-fx "lines.png" 0.125)
    blank))



;-----------------------------------------------------------
;   Global effects Run

(define muvee-global-effect
  (effect-stack
	scanlines-fx 
	(effect "CropMedia" (A))
    (effect "Perspective" (A))
	))
;-----------------------------------------------------------
;   Segment effects

(load (library "Cg.scm"))

(define muvee-segment-effect
  (cg:color-process-content-except-captions SATURATION COLOR_EFFECT COLOR_STRENGTH))


;-----------------------------------------------------------
;   Transitions
;   - bottom 35% of music loudness:
;     - blur
;   - between 35% and 80% of music loudness:
;     - hexagonal gradient wipe
;     - fade-to-white
;     - cut
;   - top-20% of music loudness:
;     - hexagonal explode
;     - cut

(define fade-to-white-tx
  (layers (A B)
    ; show input A for first half of effect
    (effect "Alpha" ()
            (input 0 A)
            (param "Alpha" 1.0 (at 0.5 0.0)))
    ; show input B for second half of effect
    (effect "Alpha" ()
            (input 0 B)
            (param "Alpha" 0.0 (at 0.5 1.0)))
    ; color fade in and fade out
    (effect-stack
      (effect "Translate" (A)
              (param "z" 0.001))
      (effect "ColorQuad" ()
              (param "a" 0.0
                     (bezier 0.5 1.0 0.0 0.0)
                     (bezier 1.0 0.0 0.0 0.0))
              (param "r" 1.0)
              (param "g" 1.0)
              (param "b" 1.0)))))

(define blur-tx
  (let ((maxblur 7.0))
    (layers (A B)
      (effect-stack
        (effect "Translate" (A)
                (param "z" -0.001))
        (effect "Blur" ()
                (input 0 A)
                (param "Amount" 0.0
                       (linear 1.0 maxblur))))
      (effect-stack
        (effect "Alpha" (B)
                (param "Alpha" 0.0
                       (linear 1.0 1.0)))
        (effect "Blur" ()
                (input 0 B)
                (param "Amount" maxblur
                       (linear 1.0 0.0)))))))



;;; hexagonal explode ;;;


(define shatter+fade+quake-tx
  (let ((move-offset (- 1.0 (* 0.125 0.6)))
        (polygon-length (+ 0.125 0.025))
        (delta-z -2.0)
        (fovy 45.0)  ; assumes 45" fovy
        (tangent (tan (deg->rad (* fovy 0.5))))
        (scale (- 1.0 (* tangent delta-z))))
    (layers (A B)
      ; quake whose amplitude decays over time
      (effect-stack
        (effect "Translate" (A)
                (param "x" 0.0 (fn (p) (* (rand -0.2 0.2) (- 1.0 p))) 30)
                (param "y" 0.0 (fn (p) (* (rand -0.2 0.2) (- 1.0 p))) 30)
                (param "z" delta-z))
        (effect "Scale" ()
                (input 0 B)
                (param "x" (* scale 1.1) (linear 1.0 scale))
                (param "y" (* scale 1.1) (linear 1.0 scale))))
      ; fade in from white
      ;(effect "ColorQuad" ()
              ;(param "a" 1.0 (bezier 1.0 0.0 1.0 1.0)))
)))

(define reverse-shatter+fade+quake-tx
  (let ((move-offset (- 1.0 (* 0.125 0.6)))
        (polygon-length (+ 0.125 0.025))
        (delta-z -2.0)
        (fovy 45.0)  ; assumes 45" fovy
        (tangent (tan (deg->rad (* fovy 0.5))))
        (scale (- 1.0 (* tangent delta-z))))
    (layers (B A)  ; quick way to swap inputs
      (effect-stack
        ; quake whose amplitude increases over time
        (effect "Translate" (A)
                (param "x" 0.0 (fn (p) (* (rand -0.2 0.2) p)) 30)
                (param "y" 0.0 (fn (p) (* (rand -0.2 0.2) p)) 30)
                (param "z"delta-z))
        ; quake whose amplitude increases over time
        (effect "Scale" ()
                (input 0 B)
                (param "x" scale (linear 1.0 (* scale 1.1)))
                (param "y" scale (linear 1.0 (* scale 1.1)))))
      ; fade out to white
      ;(effect "ColorQuad" ()
              ;(param "a" 0.0 (bezier 1.0 1.0 0.0 0.0)))
)))


(define hexagonal-explode
  (if (= EXPLODE 'on)
    (effect-selector
      (random-sequence shatter+fade+quake-tx
                     reverse-shatter+fade+quake-tx))cut))

;;; transition selection ;;;

(define muvee-transition
  (select-effect/loudness
    (step-tc 0.00 blur-tx
             0.50 (effect-selector
                    (random-sequence cut
                                     blur-tx
                                     hexagonal-explode
                                     fade-to-white-tx))
             0.80 (effect-selector
                    (looping-sequence hexagonal-explode
                                      cut)))))

;-----------------------------------------------------------
;   Text effects

(define random-direction (random-sequence -1.0 1.0))

(Captions.set-default-font-properties 0xffffffff 21 "Sansation")

(Captions.presenter (fn args
                      (Captions.Drift.direction (random-direction))
                      (apply Captions.Drift args)))


(define muvee-text-effect Captions)


;-----------------------------------------------------------
;   Title and credits

(define FOREGROUND_FX
  (effect-stack
    scanlines-fx
    (effect "Perspective" (A))))

(title-section
  (audio-clip "background.wmv" gaindb: -3.0)
  (background
    (video "background.wmv"))
  (foreground
    (fx FOREGROUND_FX))
  (text
    (align 'center 'center)
    (color 255 255 255)
    (font "-22,0,0,0,800,0,0,0,0,3,2,1,34,Sansation")
    (layout (0.10 0.10) (0.90 0.90))
    (soft-shadow  dx: 0.0  dy: 0.0  size: 4.0)))

(credits-section
  (audio-clip "background.wmv" gaindb: -3.0)
  (background
    (video "background.wmv"))
  (foreground
    (fx FOREGROUND_FX))
  (text
    (align 'center 'center)
    (color 255 255 255)
    (font "-22,0,0,0,800,0,0,0,0,3,2,1,34,Sansation")
    (layout (0.10 0.10) (0.90 0.90))
    (soft-shadow  dx: 0.0  dy: 0.0  size: 4.0)))


;;; transitions between title/credits and body ;;;

(define slow-fade-to-black-tx
  (layers (A B)
    ; show input A for first half of effect
    (effect "Alpha" ()
            (input 0 A)
            (param "Alpha" 1.0 (at 0.5 0.0)))
    ; show input B for second half of effect
    (effect "Alpha" ()
            (input 0 B)
            (param "Alpha" 0.0 (at 0.5 1.0)))
    ; color overlay with varying opacity
    (effect-stack
    scanlines-fx
      (effect "Translate" (A)
              (param "z" 0.1))
      (effect "ColorQuad" ()
              (param "a" 0.0
                     (bezier 0.45 1.0 0.0 0.0)
                     (at 0.55 1.0)
                     (bezier 1.0 0.0 1.0 1.0))
              (param "r" 0.0)
              (param "g" 0.0)
              (param "b" 0.0)))))

(define title/credits-tx-dur
  ; ranges from 0.5 to 2.0 seconds
  (+ (* (- 1.0 AVERAGE_SPEED) 1.5) 0.5))

(muvee-title-body-transition slow-fade-to-black-tx title/credits-tx-dur)

(muvee-body-credits-transition slow-fade-to-black-tx title/credits-tx-dur)