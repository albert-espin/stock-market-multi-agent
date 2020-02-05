extensions [table]

breed [speculators speculator]
breed [enterprises enterprise]


globals [

  market-money ; fons de diners del mercat

  ticks-since-statistics ; ticks des que es van mostrar dades estadístiques per darrer cop
  ticks-to-show-statistics ; temps mesurat en ticks que es triga en tornar a mostrar dades estadístiques

  ; tipus de missatges comunicatius explícits en una negociació de compravenda d'accions
  ; (també hi ha dos d'implícits, abandonar la negociació i completar la transacció, que els
  ; agents poden deduir dels fets, no cal comunicar-los explícitament)
  propose ; proposar unes característiques d'accions per part del comprador
  offer ; realitzar una oferta amb unes característiques d'accions per part del venedor
  request-for-coalition ; realitzar una petició d'unir-se a un altre agent en una coalició liderada per ell

  coalition-subordination-color ; color pels agents subordinats a una coalició
]

; atributs comuns a especuladors i empreses
turtles-own [

  current-messages ; missatges que l'agent processa a la iteració considerada actual a cada moment
  next-messages ; missatges que l'agent llegirà a la següent iteració, on els altres agents poden escriure

  money ; diners de l'agent
  start-money ; diners amb què l'agent va entrar al mercat
  best-moment-money ; màxima quantitat de diners que l'agent ha posseït en algun moment de la seva vida

  transaction-num ; nombre de transaccions totals que ha fet l'agent
  sales-num ; nombre de ventes totals que ha fet l'agent

  is-negotiating ; indica si l'agent té una negociació en marxa (a través d'una comunicació de missatges)
  has-negotiation-progressed ; indica si durant el tick actual la negociació que hi havia en marxa ha avançat
  is-waiting-for-response ; indica si l'agent està esperant una resposta en la negociació actual
  has-buyer-role ; indica si en la negociació actual l'agent té rol de comprador (o venedor en cas contrari)
  current-negotiator ; altre agent amb qui l'agent està negociant actualment

  start-tick ; tick en què l'agent ha estat creat
]

; atributs exclusius dels especuladors
speculators-own [

  risk-coefficient ; valor que mesura la tendència de l'agent a assumir riscos

  stock-quantity-per-enterprise ; taula que associa noms d'empreses amb el nombre d'accions que l'especulador té d'aquesta
  stock-value-estimation-per-enterprise ; taula que associa noms d'empreses amb una estimació de valor d'acció que l'agent fa sobre ella

  is-in-coalition ; indica si l'especulador està participant en una coalició actualment
  is-coalition-master ; indica si l'especulador és el mestre d'una coalició (qui la dirigeix)
  coalition-subordinate ; subordinate de la coalició actual de l'especulador, si ell n'és el mestre
  coalition-money-factor ; factor (entre 0 i 1) que representa el percentatge de diners de la coalició actual de l'especulador que li pertanyen
  coalition-stock-factor ; factor (entre 0 i 1) que representa el percentatge de valor en accions de la coalició actual de l'especulador que li pertanyen
  cooperation-coefficient ; factor de cooperació (entre 0 i 1), es té en compte a l'hora d'acceptar o no cooperar amb un especulador en coalició
]

; atributs exclusius de les empreses
enterprises-own [
  high-price-coefficient ; valor que mesura la tendència de l'empresa a vendre accions a preu elevat
  stock-value-estimation ; estimació de valor sobre les seves accions que l'empresa fa, a partir de les operacions passades
]


; Configuració inicial
to setup

  clear-all
  reset-ticks

  ask patches [
    set pcolor (list 200 200 200)
  ]

  set market-money 0

  set ticks-since-statistics 0
  set ticks-to-show-statistics 10000

  set propose "PROPOSE"
  set offer "OFFER"
  set request-for-coalition "REQUEST-COALITION"

  set coalition-subordination-color white

  create-speculators speculator-num [
    set next-messages []
    set is-negotiating false
    set has-negotiation-progressed false
    set is-waiting-for-response false
    set has-buyer-role false
    set current-negotiator nobody
    set money min-money-speculator + (random (max-money-speculator - min-money-speculator)) ; s'inicialitzen els diners en un rang
    set start-money money
    set best-moment-money money
    set risk-coefficient min-risk-coefficient + (random (100 * (max-risk-coefficient - min-risk-coefficient))) / 100 ; inicialitza el coeficient de risc en un rang
    set stock-quantity-per-enterprise table:make ; els especuladors comencen sense accions
    set stock-value-estimation-per-enterprise table:make ; els especuladors no poden estimar valors d'accions d'entrada
    set is-in-coalition false
    set is-coalition-master false
    set coalition-subordinate nobody
    set coalition-money-factor 0
    set coalition-stock-factor 0
    set cooperation-coefficient min-cooperation-coefficient + (random (100 * (max-cooperation-coefficient - min-cooperation-coefficient))) / 100 ; inicialitza el coeficient de cooperació en un rang
    set start-tick ticks
    setxy random-xcor random-ycor
    set shape "person business"
    set size 1.5
    set color blue ; color inicial de l'especulador
  ]

  create-enterprises enterprise-num [
    set next-messages []
    set is-negotiating false
    set has-negotiation-progressed false
    set is-waiting-for-response false
    set has-buyer-role false
    set current-negotiator nobody
    set stock-value-estimation 1
    set money min-money-enterprise + (random (max-money-enterprise - min-money-enterprise))  ; s'inicialitzen els diners en un rang
    set start-money money
    set best-moment-money money
    set high-price-coefficient min-high-price-coefficient + (random (100 * (max-high-price-coefficient - min-high-price-coefficient))) / 100 ; 'inicialitza el coeficient de preu alt en un rang
    set start-tick ticks
    setxy (-15 + (random 30)) (-15 + (random 30))
    set shape "house colonial"
    set size 3
    set color gray
  ]

end


; Actualització per tick
to go
  swap-messages
  process-messages
  act
  manage-statistics
  tick
end


; Actuar
to act

  ; els especuladors actuen
  ask speculators [

    ; si l'agent no té una negociació en marxa, intenta trobar algú amb qui iniciar una negociació
    if not is-negotiating [

      ; l'agent participa en el sorteig del mercat (li poden tocar diners)
      participate-in-raffle

      ; l'especulador deprecia (molt lleugerament) el valor estimat pel preu de les accions que encara no ha venut
      depreciate-unsold-stock

      ; l'especulador es mou
      move

      ; l'especulador gestiona la participació a la seva coalició que dirigeix, si en té (la pot trencar)
      manage-coalition

      ; intenta iniciar una negociació
      try-to-start-negotiation
    ]

    ; s'actualitza el color en funció dels diners
    update-color
  ]


  ; les empreses actuen
  ask enterprises [

    ; les empreses pateixen una variació al seu patrimoni per les activitats dutes a terme al mercat
    ; extern de la seva indústria (inversions, guanys, pèrdues, amortitzacions...)
    set money max(list min-money-enterprise (money + money * ((random 10) / 10000) -  money * ((random 10) / 10000)))

    ; s'actualitza el registre de millors diners si escau
    if money > best-moment-money [

     set best-moment-money money
    ]

    ; s'actualitza el color en funció dels diners
    update-color
  ]


end


; Fa participar l'agent en un sorteig del mercat, on a canvi d'un petit preu de participació pot guanyar molts diners
to participate-in-raffle

  ; no sempre s'acaba participant, i cal poder pagar la participació al sorteig
  if (random 100) > 95 and money > raffle-participation-money [

    set money (money - raffle-participation-money)
    pay-market raffle-participation-money

    ; la probabilitat de victòria es baixa, però si es guanya l'agent obté part dels diners del mercat
    if 1 > random (1 / win-raffle-probability) [

      let prize market-money * 0.25 + market-money * (random 50) / 100
      set market-money (market-money - prize)
      set money (money + prize)

      ; s'anota si es tenen més diners que mai
      if money > best-moment-money [

        set best-moment-money money
      ]

      print (word self "has won a prize of " prize " money units in the market's raffle!")
    ]
  ]

end



; Incrementa els fons del mercat amb la quantitat de diners passada per paràmetre
to pay-market [paid-money]

  set market-money (market-money + paid-money)
end


; Mou un agent
to move

  ; els subordinats de coalicions segueixen el rumb que marqui el mestre de coalició, no decideixen ells on anar
  if breed = speculators and is-in-coalition and not is-coalition-master [

    stop
  ]

  ; l'agent canvia de direcció amb una certa probabilitat
  if random 10 > 8 [
   rt random random 180
  ]

  ; l'agent avança
  fd 1

  ; els mestres de coalició fixen la posició dels seus subordinats
  if breed = speculators and is-in-coalition and is-coalition-master [

    let subordinate-x xcor
    let subordinate-y ycor - 1

    ask coalition-subordinate [

      set xcor subordinate-x
      set ycor subordinate-y
    ]
  ]

end



; L'agent interactua amb el seu entorn, enviant missatges a agents propers si ho estima oportú,
; amb l'objectiu d'iniciar una negociació
to try-to-start-negotiation

  ; calcula el radi de percepció de l'agent, que determinarà la seva zona de possible interacció
  let radius get-perception-radius

  ;print radius

   ; interacció per especuladors
  if breed = speculators [

     ; es localitzen els agents propers, amb què l'especulador pot interactuar
      let close-agents (other turtles with [ distance myself <= radius ])

    ; si hi ha algun agent a prop, s'intenta interactuar amb ell
    if count close-agents > 0 [

      let close-agent nobody

      ; determina si és preferible negociar amb un especulador o una empresa
      let seeks-speculator should-negotiate-with-speculator-or-enterprise

      ifelse seeks-speculator [

        set close-agent one-of close-agents with [breed = speculators]
      ]

      [

        set close-agent one-of close-agents with [breed = enterprises]
      ]

      if close-agent != nobody [

        ; si l'altre agent és un especulador
        ifelse seeks-speculator [

          ; si es determina convenient, es procedeix a sol·licitar a l'agent unir-se a ell en coalició
          ifelse should-request-coalition [

           request-coalition close-agent (list get-stock-estimated-value money)
          ]

          [
            ; es determina si és més convenient per l'agent intentar comprar o vendre accions ara mateix
            let should-ask-to-buy should-buy-or-sell

            ; si comprar sembla més oportú, s'inicia una negociació de compra
            ifelse should-ask-to-buy [

              negotiate-to-buy close-agent (list)
            ]

            ; altrament, s'inicia una negociació de venda
            [

              negotiate-to-sell close-agent (list)
            ]
          ]
        ]


        ; si l'altre agent és una empresa
        [

          ; es determina si és conveninet per l'agent intentar comprar accions ara mateix
          let should-ask-to-buy should-buy-or-sell

          ; si comprar sembla oportú, s'inicia una negociació de compra
          if should-ask-to-buy [

            negotiate-to-buy close-agent (list)
          ]
        ]
      ]
    ]
  ]

end



; Determina si és preferible començar una negociació amb un especulador o bé amb una empresa
to-report should-negotiate-with-speculator-or-enterprise

  ; es tendeix a voler vendre accions a un especulador si es té un alt valor estimat en accions,
  ; i a voler comprar accions a una empresa si es tenen poques accions però suficients diners
  let should-negotiate-with-speculator 3 * get-stock-estimated-value > money

  ; s'aporta certa aleatorietat
  if random 100 > 97 [

    set should-negotiate-with-speculator (not should-negotiate-with-speculator)
  ]

  report should-negotiate-with-speculator

end


; Determina si és oportú per a un especulador unir-se a un altre especulador en coalició
to-report should-request-coalition

  ; cal que les coalicions estiguin permeses
  if are-coalitions-allowed [

    ; no pot formar part de dues coalicions alhora
    if not is-in-coalition [

      ; es té en compte un factor global de probabilitat de voler formar coalició
      let coalition-probability request-coalition-probability-factor / 10000

      ; la probabilitat augmenta en situacions d'un cert bloqueig per l'agent (com tenir un valor estimat en accions molt gran però
      ; pocs diners)
      set coalition-probability (coalition-probability * min (list 0.5 (max (list 3 (get-stock-estimated-value / (money + 0.01))))))

      report (100 * coalition-probability) > random 100
    ]
  ]

    report false
end


; L'especulador deprecia (molt lleugerament) el valor estimat pel preu de les accions que encara no ha venut,
; sota el raonament que si no ha pogut vendre fins ara les seves accions deu ser perquè valen menys del que ell
; creu i per tant demana per elles
to depreciate-unsold-stock

  let stock-num 0
  let index 0

  let enterprise-ids (table:keys stock-value-estimation-per-enterprise)

  loop [

    ; s'atura quan ha recorregut tota la taula
    if index >= table:length stock-value-estimation-per-enterprise [
      stop
    ]

    ; empresa de la iteració actual
    let enterprise-id (item index enterprise-ids)

    ; deprecia molt lleugerament l'estimació de valor de l'acció
    table:put stock-value-estimation-per-enterprise enterprise-id (max (list 0.1 (0.99 * (table:get stock-value-estimation-per-enterprise enterprise-id))))

    ; incrementa l'índex
    set index (index + 1)
  ]

end


; Obté i retorna el nombre d'accions totals d'un especulador
to-report get-stock-num

  let stock-num 0
  let index 0

  let enterprise-ids (table:keys stock-quantity-per-enterprise)

  loop [

    ; retorna el nombre d'accions totals quan ha recorregut tota la taula
    if index >= table:length stock-quantity-per-enterprise [
      report stock-num
    ]

    ; empresa de la iteració actual
    let enterprise-id (item index enterprise-ids)

    ; incrementa el nombre d'accions amb les de l'empresa de la iteració actual
    set stock-num (stock-num + table:get stock-quantity-per-enterprise enterprise-id)

    ; incrementa l'índex
    set index (index + 1)
  ]

end


; Obté i retorna el valor total que un especulador estima per al conjunt de les accions que posseeix
to-report get-stock-estimated-value

  let estimated-value 0
  let index 0

  let enterprise-ids (table:keys stock-quantity-per-enterprise)

  loop [

    ; retorna el valor estimat total quan ha recorregut tota la taula
    if index >= table:length stock-quantity-per-enterprise [
      report estimated-value
    ]

    ; empresa de la iteració actual
    let enterprise-id (item index enterprise-ids)

    ; incrementa el valor estimat amb el de les accions que es tenen de l'empresa de la iteració actual
    set estimated-value (estimated-value + (table:get stock-quantity-per-enterprise enterprise-id) * (table:get-or-default stock-value-estimation-per-enterprise enterprise-id 1))

    ; incrementa l'índex
    set index (index + 1)
  ]

end

; Obté i retorna l'estimació del valor mig de cada acció individual de l'especulador
to-report get-stock-average-estimated-value

  if table:length stock-value-estimation-per-enterprise = 0 [

    report 1
  ]

  report mean table:values stock-value-estimation-per-enterprise

end

; Calcula i retorna el radi de percepció d'un agent
to-report get-perception-radius


  let perception-radius 0

  ; pels especuladors, el radi de percepció es calcula a partir del nombre total d'accions (major com més accions tingui l'agent)
  if breed = speculators [

    set perception-radius (log (get-stock-num + 1) 10)
  ]

  ; per les empreses, el radi de percepció es calcula a partir dels seus diners (major com més diners tingui l'agent)
  if breed = enterprises [

    set perception-radius (log (get-stock-num + 1) 100)
  ]


    ; limitació del radi per no ser menor que el valor mínim acceptable
    ifelse perception-radius < min-perception-radius [

      set perception-radius min-perception-radius
    ]

    [

      ; limitació del radi per no ser major que el valor màxim acceptable
      if perception-radius > max-perception-radius [

        set perception-radius max-perception-radius
      ]
    ]


  report perception-radius

end


; Obté i retorna el total de diners dels especuladors
to-report get-all-speculators-money

  let total-money 0

  ask speculators [

   set total-money (total-money + money)
  ]

  report total-money

end


; Obté i retorna el total de diners de les empreses
to-report get-all-enterprises-money

  let total-money 0

  ask enterprises [

   set total-money (total-money + money)
  ]

  report total-money

end


; Obté i retorna els diners de l'especulador més ric
to-report get-money-of-richest-speculator

  let max-money 0

  ask speculators [

    if money > max-money [

      set max-money money
    ]
  ]

  report max-money

end


; Obté i retorna els diners de l'empresa més rica
to-report get-money-of-richest-enterprise

  let max-money 0

  ask enterprises [

    if money > max-money [

      set max-money money
    ]
  ]

  report max-money

end


; Obté i retorna els diners de l'especulador més pobre
to-report get-money-of-poorest-speculator

  let min-money 0

  ask speculators [

    if min-money = 0 or money < min-money [

      ; es descarten subordinats de coalicions
      if not is-in-coalition or is-coalition-master [

        set min-money money
      ]
    ]
  ]

  report min-money

end



; Obté i retorna els diners de l'empresa més pobra
to-report get-money-of-poorest-enterprise

  let min-money 0

  ask enterprises [

    if min-money = 0 or money < min-money [

      set min-money money
    ]
  ]

  report min-money

end


; Obté i retorna els diners que té de mitja un especulador
to-report get-speculators-average-money

  if count speculators > 1 [

    let money-list (list)

    ask speculators [

      set money-list lput money money-list
    ]

    report mean money-list
  ]

  report 0

end


; Obté i retorna els diners que té de mitja una empresa
to-report get-enterprises-average-money

  if count enterprises > 1 [

    let money-list (list)

    ask enterprises [

      set money-list lput money money-list
    ]

    report mean money-list

  ]

  report 0

end


; Obté i retorna els diners que té de mitja una coalició d'especuladors
to-report get-speculator-coalitions-average-money

  if count speculators > 1 [

    let money-list (list)

    ask speculators [

      if is-coalition-master [

        set money-list lput money money-list
      ]
    ]

    if length money-list > 0 [

      report mean money-list
    ]
  ]

  report 0

end


; Obté i retorna la desviació estàndard dels diners dels especuladors
to-report get-speculators-money-standard-deviation

  if count speculators > 1 [

    let money-list (list)

    ask speculators [

      set money-list lput money money-list
    ]

    report standard-deviation money-list

  ]

  report 0

end



; Obté i retorna la deviació estàndard dels diners de les empreses
to-report get-enterprises-money-standard-deviation

  if count enterprises > 1 [

    let money-list (list)

    ask enterprises [

      set money-list lput money money-list
    ]

    report standard-deviation money-list
  ]

  report 0

end


; Obté i retorna els diners que tenen de mitja els especuladors amb coeficient de risc dins del rang especificat
to-report get-average-money-of-speculators-with-risk-coefficient-in-range [min-coefficient max-coefficient]

  let money-list (list)

  ask speculators [

    if risk-coefficient >= min-coefficient and risk-coefficient <= max-coefficient [

      ; no es tenen en compte els subordinats de coalicions
      if not is-in-coalition or is-coalition-master [

        set money-list lput money money-list
      ]
    ]
  ]

  if length money-list = 0 [

    report 0
  ]

  report mean money-list

end

; Obté i retorna els diners que tenen de mitja els especuladors amb coeficient de risc baix
to-report get-average-money-of-speculators-with-low-risk-coefficient

  report get-average-money-of-speculators-with-risk-coefficient-in-range min-risk-coefficient (min-risk-coefficient + (max-risk-coefficient - min-risk-coefficient) / 3)
end


; Obté i retorna els diners que tenen de mitja els especuladors amb coeficient de risc mig
to-report get-average-money-of-speculators-with-intermediate-risk-coefficient

  report get-average-money-of-speculators-with-risk-coefficient-in-range (min-risk-coefficient + (max-risk-coefficient - min-risk-coefficient) / 3) (max-risk-coefficient - (max-risk-coefficient - min-risk-coefficient) / 3)
end


; Obté i retorna els diners que tenen de mitja els especuladors amb coeficient de risc elevat
to-report get-average-money-of-speculators-with-high-risk-coefficient

  report get-average-money-of-speculators-with-risk-coefficient-in-range (max-risk-coefficient - (max-risk-coefficient - min-risk-coefficient) / 3) max-risk-coefficient
end


; Obté i retorna els diners que tenen de mitja les empreses amb coeficient d'alt preu dins del rang especificat
to-report get-average-money-of-enterprises-with-high-price-coefficient-in-range [min-coefficient max-coefficient]

    let money-list (list)

    ask enterprises [

      if high-price-coefficient >= min-coefficient and high-price-coefficient <= max-coefficient [

        set money-list lput money money-list
      ]
    ]

    if length money-list = 0 [

      report 0
    ]

    report mean money-list

end

; Obté i retorna els diners que tenen de mitja les empreses amb coeficient d'alt preu baix
to-report get-average-money-of-enterprises-with-low-high-price-coefficient

  report get-average-money-of-enterprises-with-high-price-coefficient-in-range min-high-price-coefficient (min-high-price-coefficient + (max-high-price-coefficient - min-high-price-coefficient) / 3)
end


; Obté i retorna els diners que tenen de mitja les empreses amb coeficient d'alt preu mig
to-report get-average-money-of-enterprises-with-intermediate-high-price-coefficient

  report get-average-money-of-enterprises-with-high-price-coefficient-in-range (min-high-price-coefficient + (max-high-price-coefficient - min-high-price-coefficient) / 3) (max-high-price-coefficient - (max-high-price-coefficient - min-high-price-coefficient) / 3)
end


; Obté i retorna els diners que tenen de mitja les empreses amb coeficient d'alt preu elevat
to-report get-average-money-of-enterprises-with-high-high-price-coefficient

  report get-average-money-of-enterprises-with-high-price-coefficient-in-range (max-high-price-coefficient - (max-high-price-coefficient - min-high-price-coefficient) / 3) max-high-price-coefficient
end



; Obté i retorna els diners que tenen de mitja les empreses que van començar amb diners inicials en el rang especificat
to-report get-average-money-of-enterprises-with-start-money-in-range [min-start-money max-start-money]

    let money-list (list)

    ask enterprises [

      if start-money >= min-start-money and start-money <= max-start-money [

        set money-list lput money money-list
      ]
    ]

    if length money-list = 0 [

      report 0
    ]

    report mean money-list

end

; Obté i retorna els diners que tenen de mitja els especuladors que inicialment eren pobres
to-report get-average-money-of-initially-poor-speculators

  report get-average-money-of-speculators-with-start-money-in-range min-money-speculator (min-money-speculator + (max-money-speculator - min-money-speculator) / 3)
end

; Obté i retorna els diners que tenen de mitja els especuladors que inicialment eren econòmicament estàndard (ni rics ni pobres)
to-report get-average-money-of-initially-standard-speculators

  report get-average-money-of-speculators-with-start-money-in-range (min-money-speculator + (max-money-speculator - min-money-speculator) / 3) (max-money-speculator - (max-money-speculator  - min-money-speculator) / 3)
end

; Obté i retorna els diners que tenen de mitja els especuladors que inicialment eren rics
to-report get-average-money-of-initially-rich-speculators

  report get-average-money-of-speculators-with-start-money-in-range (max-money-speculator - (max-money-speculator  - min-money-speculator) / 3) max-money-speculator
end



; Obté i retorna els diners que tenen de mitja els especuladors que van començar amb diners inicials en el rang especificat
to-report get-average-money-of-speculators-with-start-money-in-range [min-start-money max-start-money]

    let money-list (list)

    ask speculators [

      if start-money >= min-start-money and start-money <= max-start-money [

        set money-list lput money money-list
      ]
    ]

    if length money-list = 0 [

      report 0
    ]

    report mean money-list

end

; Obté i retorna els diners que tenen de mitja les empreses que inicialment eren pobres
to-report get-average-money-of-initially-poor-enterprises

  report get-average-money-of-enterprises-with-start-money-in-range min-money-enterprise (min-money-enterprise + (max-money-enterprise - min-money-enterprise) / 3)
end

; Obté i retorna els diners que tenen de mitja les empreses que inicialment eren econòmicament estàndard (ni riques ni pobres)
to-report get-average-money-of-initially-standard-enterprises

  report get-average-money-of-enterprises-with-start-money-in-range (min-money-enterprise + (max-money-enterprise - min-money-enterprise) / 3) (max-money-enterprise - (max-money-enterprise  - min-money-enterprise) / 3)
end

; Obté i retorna els diners que tenen de mitja les empreses que inicialment eren riques
to-report get-average-money-of-initially-rich-enterprises

  report get-average-money-of-enterprises-with-start-money-in-range (max-money-enterprise - (max-money-enterprise  - min-money-enterprise) / 3) max-money-enterprise
end



; Obté i retorna la mitja dels valors estimats que els especuladors donen a les seves accions
to-report get-speculators-stock-average-value-estimation

  let values (list)

  ask speculators [

    set values lput get-stock-average-estimated-value values
  ]

  if length values = 0 [

    report 1
  ]

  report mean values

end



; Obté i retorna la mitja dels valors estimats que les empreses donen a les seves accions
to-report get-enterprises-stock-average-value-estimation

  let values (list)

  ask enterprises [

    set values lput stock-value-estimation values
  ]

  if length values = 0 [

    report 1
  ]

  report mean values

end


; Obté i retorna el valor mig d'una acció del mercat, tenint en compte l'especulació sobre el valor
; tant d'especuladors com d'empreses
to-report get-market-stock-average-value-estimation

  report (get-speculators-stock-average-value-estimation + get-enterprises-stock-average-value-estimation) / 2

end


; Obté i retorna el nombre total de transaccions dutes a terme al mercat
to-report get-market-transaction-num

  let total-transaction-num 0

  ask turtles [

   set total-transaction-num (total-transaction-num + transaction-num)
  ]

  report total-transaction-num
end


; Determina si és preferible comprar o vendre
to-report should-buy-or-sell


  ; si no té cap acció, només es voldrà comprar
  if get-stock-num = 0 [

    report true
  ]

  ; si es tenen més diners que el que s'estima que és té en valor d'accions es tendeix a comprar, altrament a vendre
  let should-buy money >= 5 * get-stock-estimated-value

  ; es dóna un marge d'atzar per poder canviar d'idea
  if random 10 > 7 [

    set should-buy (not should-buy)
  ]

  report should-buy

end




; Realitza un pas de negociació de compra d'accions entre un especulador i un altre agent (especulador o empresa)
to negotiate-to-buy [potential-seller previous-offer]

  ; es determinen les condicions de la proposta de compra que es vol fer, amb el nom de l'empresa
  ; de qui es volen adquirir accions, la quantitat que es vol comprar i el preu; es posa en una llista
  let buy-proposal determine-buy-proposal-conditions potential-seller previous-offer

  ; només si s'han pogut determinat condicions acceptables s'acaba negociant
  if length buy-proposal != 0 [

    ; s'envia un missatge de proposta de compra amb la llista de característiques de la mateixa
    send-message potential-seller propose buy-proposal

    ; es marca la negociació com a iniciada (per si encara no ho estava)
    set is-negotiating true

    ; es marca que la negociació acaba de progressar
    set has-negotiation-progressed true

    ; es marca que s'espera resposta (s'esperarà un torn)
    set is-waiting-for-response true

    ; es marca que l'agent vol actuar com a comprador
    set has-buyer-role true

    ; l'agent amb qui es vol negociar és aquell a qui es vol comprar
    set current-negotiator potential-seller
  ]

end


; Determina les condicions o característiques d'una proposta de compra que vol fer un especulador,
; i es retornen en forma de llista ordenada, amb l'id de l'empresa de les accions, seguit del nombre
; d'accions i finalment amb el preu que es disposa a pagar; es pot tenir en compte l'oferta prèvia
to-report determine-buy-proposal-conditions [potential-seller previous-offer]

  ; el venedor potencial ha de seguir existint
  if is-turtle? potential-seller [

    let enterprise-id nobody

    let is-potential-seller-enterprise false


    ask potential-seller [

      set is-potential-seller-enterprise (breed = enterprises)
    ]


    ; si el venedor potencial és una empresa, es demanaran accions d'aquella empresa
    ifelse is-potential-seller-enterprise [

      ask potential-seller [

        set enterprise-id who
      ]
    ]

    ; altrament s'ha de decidir de quina empresa es volen demanar accions
    [

       set enterprise-id choose-enterprise-to-buy previous-offer
    ]

    ; si no s'ha descartat l'operació
    if enterprise-id != nobody [

      let stock-num 0

      ; per decidir el nombre d'accions a comprar i el preu, cal tenir en compte:
      ; - quantitat d'accions que ja es tenen de l'empresa
      ; - diners totals que es tenen
      ; - estimació de valor que es fa per l'acció de l'empresa
      ; - coeficient de risc (voldrà més accions si el coeficient és gran)
      ; - l'oferta anterior (si n'hi ha hagut)

      ; quantitat d'accions que ja es tenen de l'empresa
      let owned-stock-num table:get-or-default stock-quantity-per-enterprise enterprise-id 0

      ; factor que té en compte els diners i les accions que es tenen ja de l'empresa
      let money-and-owned-stock-factor money * 0.1 - owned-stock-num * 0.3

      ; estimació de valor que es fa per l'acció de l'empresa
      let estimated-stock-value table:get-or-default stock-value-estimation-per-enterprise enterprise-id 1

      ; es completa la fórmula tenint en compte l'estimació de valor de les accions de l'empresa i el coeficient de risc
      let possible-stock-num money-and-owned-stock-factor / estimated-stock-value + (money-and-owned-stock-factor * risk-coefficient) * 0.3

      ; es fixa un mínim d'accions
      set stock-num max (list 100 possible-stock-num)

      ; aplicació d'una certa aleatorietat
      set stock-num round (stock-num * 0.5 + ((stock-num * random 100) / 100))

      ; si hi ha hagut una oferta anterior, no se sobrepassa la quantitat oferta (potser és tot el que podien oferir)
      if length previous-offer != 0 [
        set stock-num round (min (list stock-num (item 1 previous-offer)))
      ]

      ; es parteix d'un preu baix, a veure si el venedor accepta (però no tan baix com per esgotar fàcilment la seva paciència)
      ; el preu inicial es calcula en base al nombre d'accions i a una estimació del seu valor individual
      let price stock-num * estimated-stock-value * ((40 + random 25) / 100)

      ; si hi ha hagut oferta prèvia, s'intenta cedir una mica a ella per evitar esgotar la paciència de l'altra part
      if length previous-offer != 0 [

        let offered-stock-num (item 1 previous-offer)
        let offered-price (item 2 previous-offer)

        ; si l'oferta és igual o millor que la proposta que es volia fer, s'accepta immediatament
        let can-accept-offer offered-stock-num >= stock-num and offered-price <= price

        ; si l'oferta és convincent (s'apropa suficientment a les condicions volgudes), es pot arribar a acceptar
        if not can-accept-offer [

          set can-accept-offer (stock-num - offered-stock-num < 0.3 * stock-num * (1 - risk-coefficient)) and (offered-price - price < 3 * price * (1 - risk-coefficient))
        ]

        ; no es poden pagar més diners dels que es tenen
        set can-accept-offer (can-accept-offer and money > offered-price)

        ; si s'ha decidit acceptar, es duu a terme la transacció
        ifelse can-accept-offer [

          make-transaction potential-seller previous-offer

          report (list)
        ]

        ; en cas contrari es planteja una nova proposta de comprador a venedor
        [

          let negotiation-weight (25 + random 30) / 100
          let conserved-weight 1 - negotiation-weight

          set stock-num round (stock-num * conserved-weight + offered-stock-num * negotiation-weight)
          set price max (list transaction-tax (price * conserved-weight + offered-price * negotiation-weight))
        ]
      ]


      ; no es poden oferir més diners dels disponibles (amb un cert marge)
      set price min (list price (money * 0.8))

      report (list enterprise-id stock-num price)
    ]
  ]

  report (list)

end


; Donada la necessitat d'escollir una empresa de qui demanar accions, fa la tria que es consideri més raonable
to-report choose-enterprise-to-buy [previous-offer]

  let enterprise-id nobody

  ; si hi ha hagut una oferta prèvia amb accions d'una empresa determinada, es decideix si acceptar-ho o no
  ifelse length previous-offer != 0 [

    set enterprise-id (item 0 previous-offer)

    ; es defineix una probabilitat de declinar voler accions de l'empresa, que augmenta si l'agent ja té moltes accions seves
    let decline-probability 0.1

    let stock-num max (list 1 get-stock-num)

    set decline-probability (decline-probability + (table:get-or-default stock-quantity-per-enterprise enterprise-id 0) / stock-num)

    ; si s'estima oportú, es declina seguir endavant
    if decline-probability * 100 > random 100 [

      report nobody
    ]

    ; altrament s'accepta l'empresa de l'oferta anterior
    report enterprise-id
  ]

  ; si no hi ha hagut una oferta anterior
  [
    ; tria d'una empresa a l'atzar
    let chosen-enterprise one-of enterprises

    ask chosen-enterprise [

      set enterprise-id who
    ]
    report enterprise-id
  ]

end


; Realitza un pas de negociació de venda d'accions entre un agent i un altre
to negotiate-to-sell [potential-buyer previous-proposal]

  ; es determinen les condicions de la proposta de compra que es vol fer, amb el nom de l'empresa
  ; de qui es volen adquirir accions, la quantitat que es vol comprar i el preu; es posa en una llista
  let sell-offer determine-sell-offer-conditions potential-buyer previous-proposal

  ; només si s'han pogut determinat condicions acceptables s'acaba negociant
  if length sell-offer != 0 [

    ; s'envia un missatge d'oferta amb la llista de característiques de la mateixa
    send-message potential-buyer offer sell-offer

    ; es marca la negociació com a iniciada (per si encara no ho estava)
    set is-negotiating true

    ; es marca que la negociació acaba de progressar
    set has-negotiation-progressed true

    ; es marca que s'espera resposta (s'esperarà un torn)
    set is-waiting-for-response true

    ; es marca que l'agent no vol actuar com a comprador (sinó com a venedor)
    set has-buyer-role false

    ; l'agent amb qui es vol negociar és aquell a qui es vol vendre
    set current-negotiator potential-buyer
  ]

end



; Determina les condicions o característiques d'una oferta de venda que vol fer un agent,
; i es retornen en forma de llista ordenada, amb l'id de l'empresa de les accions, seguit del nombre
; d'accions i finalment amb el preu que es disposa a acceptar; es pot tenir en compte una proposta prèvia
to-report determine-sell-offer-conditions [potential-buyer previous-proposal]

  ; el comprador potencial ha de seguir existint
  if is-turtle? potential-buyer [

    let enterprise-id nobody
    let max-stock-to-offer 999999

    ; si s'és una empresa, s'oferiran accions de l'empresa
    ifelse breed = enterprises [

      set enterprise-id who
    ]

    ; altrament s'ha de decidir de quina empresa es volen oferir accions
    [

      set enterprise-id choose-enterprise-to-sell previous-proposal

      if enterprise-id != nobody [

        ; només es poden oferir tantes accions com es tenen
        set max-stock-to-offer table:get stock-quantity-per-enterprise enterprise-id
      ]
    ]

    ; si no s'ha descartat l'operació
    if enterprise-id != nobody [

      ; per decidir el nombre d'accions a oferir i el preu de l'oferta, cal tenir en compte:
      ; - estimació de valor que es fa per l'acció de l'empresa
      ; - coeficient de risc si s'és especulador o bé coeficient de preu alt si s'és empresa
      ;   (voldrà vendre les accions a més preu si el coeficient és gran)
      ; - la proposta anterior (si n'hi ha hagut)


      let stock-num 0
      let price 0

      ; si no hi ha hagut una proposta anterior
      ifelse length previous-proposal = 0 [

        ; es fixa un preu inicial molt elevat, proporcional al màxim nombre de diners que pot tenir un especulador d'inici
        set price (max-money-speculator * 0.5 + (max-money-speculator * random 200) / 100)

        let estimated-stock-value 0
        let coefficient 0

        ifelse breed = speculators [

          set estimated-stock-value table:get-or-default stock-value-estimation-per-enterprise enterprise-id 1
          set coefficient risk-coefficient
        ]

        [
          if breed = enterprises [

            set estimated-stock-value stock-value-estimation
            set coefficient high-price-coefficient
          ]
        ]


        ; nombre d'accions que s'haurien d'oferir pel preu fixat abans si es respectés el valor per acció estimat
        let estimated-stock-num (price / estimated-stock-value)

        ; es fa dependre el nombre d'accions del coeficient (de risc o preu alt; com més alt menys accions voldrà vendre al preu fixat)
        set stock-num max (list 1 (estimated-stock-num * (1 - coefficient)))

        ; es limita al nombre d'accions que es tenen
        set stock-num round (min (list stock-num max-stock-to-offer))
      ]

      ; si hi ha hagut una proposta anterior
      [

        let proposed-enterprise-id (item 0 previous-proposal)
        let proposed-stock-num (item 1 previous-proposal)
        let proposed-price (item 2 previous-proposal)


        ; s'oferirà un nombre d'accions relativament proper a la proposta rebuda
        set stock-num (proposed-stock-num) + ((random (50 * proposed-stock-num)) / 100) - ((random (25 * proposed-stock-num)) / 100)

        ; es limita al nombre d'accions que es tenen
        set stock-num round (min (list stock-num max-stock-to-offer))

        let estimated-stock-value 0
        let coefficient 0

        ifelse breed = speculators [

          set estimated-stock-value table:get-or-default stock-value-estimation-per-enterprise enterprise-id 1
          set coefficient risk-coefficient
        ]

        [
          if breed = enterprises [

            set estimated-stock-value stock-value-estimation
            set coefficient high-price-coefficient
          ]
        ]

        ; preu que s'estima que haurien de costar el nombre d'accions fixat al preu per acció que estima l'agent
        let estimated-price stock-num * estimated-stock-value

        ; s'encareix el preu per a la oferta, més com més intens sigui el coeficient de risc o preu car de l'agent
        set price estimated-price + 0.5 * coefficient * estimated-price

        ; les empreses ofereixen un descompte per incentivar la venda en grans magnituds
        ifelse breed = enterprises [

         set price price * (0.5 + (random 30) / 100)
        ]

        ; els especuladors desesperats que tenen accions però molt pocs diners accedeixen també a rebaixar el preu
        ; per garantir la venda
        [

          set price price * 0.3 + price * 0.7 * ((min (list start-money money)) / start-money)
        ]


        ; si la proposta anterior és comptabile i igual o millor que l'oferta que s'anava a fer, s'accepta immediatament
        if is-negotiating and proposed-enterprise-id = enterprise-id and proposed-stock-num <= stock-num and proposed-price >= price [

          let seller self

          ; es demana al mercat que dugui a terme la transacció, amb el comprador pagant al venedor
          ask potential-buyer [

            make-transaction seller previous-proposal
          ]

          report (list)
        ]
      ]

      ; si hi ha hagut proposta prèvia, s'intenta cedir una mica a ella per evitar esgotar la paciència de l'altra part
      if length previous-proposal != 0 [

        let proposed-stock-num (item 1 previous-proposal)
        let proposed-price (item 2 previous-proposal)

        let negotiation-weight (25 + random 30) / 100
        let conserved-weight 1 - negotiation-weight

        set stock-num round (stock-num * conserved-weight + proposed-stock-num * negotiation-weight)

        ; cal limitar el nombre d'accions que s'ofereixen al nombre d'accions que es tenen d'una empresa
        if breed = speculators [

         set stock-num min (list stock-num table:get stock-quantity-per-enterprise enterprise-id)
        ]


        set price max (list transaction-tax (price * conserved-weight + proposed-price * negotiation-weight))
      ]

      report (list enterprise-id stock-num price)
    ]
  ]

  report (list)

end


; Donada la necessitat d'escollir una empresa de qui vendre accions, fa la tria que es consideri més raonable
to-report choose-enterprise-to-sell [previous-proposal]

  let enterprise-id nobody

  ; si hi ha hagut una propsta prèvia amb accions d'una empresa determinada, es decideix si acceptar-ho o no
  if length previous-proposal != 0 [

    ; si es tenen accions de l'empresa
    if table:get-or-default stock-quantity-per-enterprise enterprise-id 0 > 0 [

      set enterprise-id (item 0 previous-proposal)

      ; es defineix una probabilitat de declinar voler vendre accions de l'empresa, que disminueix si es tenen moltes accions de l'empresa
      let decline-probability 0.3

      let stock-num max (list 1 get-stock-num)

      set decline-probability (decline-probability - (table:get-or-default stock-quantity-per-enterprise enterprise-id 0) / stock-num)

      ; si s'estima oportú, es declina seguir endavant
      if decline-probability * 100 > random 100 [

        report nobody
      ]

      ; altrament s'accepta l'empresa de la proposta anterior
      report enterprise-id
  ]
 ]


  ; cal tenir accions d'alguna empresa
  if table:length stock-quantity-per-enterprise > 0 [

    ; tria d'una empresa a l'atzar (d'entre aquelles de les quals es tenen accions)
    set enterprise-id one-of table:keys stock-quantity-per-enterprise

    ; es descarta en el cas extrem de no tenir cap acció restant
    if table:get stock-quantity-per-enterprise enterprise-id <= 0 [

      set enterprise-id nobody
    ]
 ]
  report enterprise-id


end



; Realitza una transacció en què l'agent paga a un venedor i aquest li dóna la quantitat d'accions ofertes d'una empresa
to make-transaction [seller sell-offer]

  let offer-enterprise (item 0 sell-offer)
  let offer-quantity (item 1 sell-offer)
  let offer-price (item 2 sell-offer)

  ; s'estima el valor per acció de l'empresa com el preu pel qual es compra una acció individual
  let estimated-stock-value offer-quantity / offer-price

  ; resta els diners de compra al comprador
  set money (money - offer-price)

  ; es fixa el cost de transacció a pagar al mercat (amb part variable, depenent de l'import a pagar, i una part fixa)
  let market-transaction-cost 0.01 * offer-price + transaction-tax

  ; es paga al mercat per fer la transacció
  pay-market market-transaction-cost

  ask seller [

    ; suma els diners de venda al venedor
    set money (money + offer-price - market-transaction-cost)

    ; si l'agent té més diners que mai, ho anota
    if best-moment-money < money [

     set best-moment-money money
    ]

    if breed = speculators [

     ; el venedor entrega les accions de l'empresa acordada
     table:put stock-quantity-per-enterprise offer-enterprise ((table:get stock-quantity-per-enterprise offer-enterprise) - offer-quantity)

     ; s'actualitza el valor estimat d'acció (mantenint en certa consideració el valor previ)
     table:put stock-value-estimation-per-enterprise offer-enterprise ((table:get-or-default stock-value-estimation-per-enterprise offer-enterprise 1) * 0.5) + estimated-stock-value * 0.5
    ]

    if breed = enterprises [

     ; s'actualitza el valor estimat d'acció (mantenint en certa consideració el valor previ)
     set stock-value-estimation (stock-value-estimation * 0.5 + estimated-stock-value * 0.5)
    ]

    ; s'augmenta el nombre de transaccions realitzades
    set transaction-num (transaction-num + 1)

    ; s'augmenta el nombre de vendes realitzades
    set sales-num (sales-num + 1)

    ; la negociació actual ha conclòs
    stop-current-negotiation
  ]

  ; el comprador aconsegueix les accions
  table:put stock-quantity-per-enterprise offer-enterprise ((table:get-or-default stock-quantity-per-enterprise offer-enterprise 0) + offer-quantity)

  ; s'actualitza el valor estimat d'acció (mantenint en certa consideració el valor previ)
  table:put stock-value-estimation-per-enterprise offer-enterprise ((table:get-or-default stock-value-estimation-per-enterprise offer-enterprise 1) * 0.5) + estimated-stock-value * 0.5

  ; s'augmenta el nombre de transaccions realitzades
  set transaction-num (transaction-num + 1)

  ; la negociació actual ha conclòs
  stop-current-negotiation

  ; mostra la transacció realitzada
  if show-protocol-messages [

    print (word self " -> " seller  ":  MAKE-TRANSACTION " sell-offer)

    print (word "total market money: " market-money)
  ]
end



; Fa que un especulador demani a un altre unir-se a una coalició
to request-coalition [other-speculator request-terms]

  ; envia el missatge
  send-message other-speculator request-for-coalition request-terms

  ; es marca la negociació com a iniciada (per si encara no ho estava)
  set is-negotiating true

  ; es marca que la negociació acaba de progressar
  set has-negotiation-progressed true

  ; es marca que s'espera resposta (s'esperarà un torn)
  set is-waiting-for-response true

  ; l'agent amb qui es vol negociar és aquell a qui es vol formar coalició
  set current-negotiator other-speculator

end


; Fa que un especulador formi una coalició, a la qual dirigirà un subordinat
to make-coalition [subordinate terms]

  ; s'inicia el període de coalició
  set is-in-coalition true

  ; l'agent és el mestre de la coalició
  set is-coalition-master true

  ; l'altre agent actuarà com a subordinat
  set coalition-subordinate subordinate

  let subordinate-stock-quantities table:make

  let subordinate-money 0

  ask subordinate [

    set is-in-coalition true

    set color coalition-subordination-color

    set subordinate-stock-quantities stock-quantity-per-enterprise

    set subordinate-money money
  ]

  ; factor entre 0 i 1 que representa quin percentatge de diners aportats a la coalició correspon al mestre
  ; (la resta al subordinat); la proporció es recuperarà amb els diners finals quan s'acabi la coalició
  set coalition-money-factor money / (money + (item 1 terms) + 0.1)

    ; factor entre 0 i 1 que representa quin percentatge d'accions (valor estimat) aportats a la coalició correspon al mestre
  ; (la resta al subordinat); la proporció es recuperarà amb les accions finals quan s'acabi la coalició
  set coalition-stock-factor 0.5

  if get-stock-estimated-value != 0 and (item 0 terms) != 0 [

    set coalition-stock-factor get-stock-estimated-value / (get-stock-estimated-value + (item 0 terms) + 0.1)
  ]

  let index 0

  let enterprise-ids table:keys subordinate-stock-quantities

  ; el subordinat dóna tots els diners al mestre
  set money subordinate-money

  ; el subordinat abona les seves accions al mestre
  while [index < table:length subordinate-stock-quantities] [

    let enterprise-id (item index enterprise-ids)

    table:put stock-quantity-per-enterprise enterprise-id ((table:get-or-default stock-quantity-per-enterprise enterprise-id 0) + (table:get subordinate-stock-quantities enterprise-id))

    set index (index + 1)
  ]

  ; el subordinat ho ha donat tot (recuperarà una part proporcional a la seva aportació quan s'acabi la coalició)
  ask subordinate [

    table:clear stock-quantity-per-enterprise

    table:clear stock-value-estimation-per-enterprise

    set money 0

    ; la negociació actual ha conclòs
    stop-current-negotiation
  ]

  ; la negociació actual ha conclòs
  stop-current-negotiation

  ; es fa públic el fet de formar la coalició
  print (word self " and " coalition-subordinate " have formed a coalition.")

end


; Fa que un especulador gestioni la coalició que dirigeix, si en té una
to manage-coalition

  if is-coalition-master [

    ; quan es tenen molts diners i poques accions, la situació és força còmode com per poder trencar la coalició
    ; (la probabilitat de trencar-la també augmenta amb un coeficient de cooperació baix)
    let break-coalition-probability  (1 - cooperation-coefficient) * (min (list 0.5 (max (list 3 (money / (get-stock-estimated-value + 1))))))

    ; si es donen les circumstàncies, es trenca la coalició
    if break-coalition-probability > random 1000 [

      break-coalition
    ]
  ]

end


; Fa que un especulador trenqui la seva coalició
to break-coalition

  ; només els mestres poden trencar les coalicions
  if is-coalition-master [

    let subordinate-money money * (1 - coalition-money-factor)
    let subordinate-stock-factor 1 - coalition-stock-factor

    ask coalition-subordinate [

      ; es dóna al subordinat la part de diners que li pertoquen en base a la seva aportació inicial a la coalició
      set money subordinate-money

      let index 0

      let enterprise-ids table:keys stock-quantity-per-enterprise

      ; el subordinat es queda amb la part d'accions que li pertoquen
      while [index < table:length stock-quantity-per-enterprise] [

        let enterprise-id (item index enterprise-ids)

        table:put stock-quantity-per-enterprise enterprise-id round ((table:get stock-quantity-per-enterprise enterprise-id) * subordinate-stock-factor)

        set index (index + 1)
      ]
    ]

    ; el mestre es queda amb la part de diners que li pertoca
    set money money * coalition-money-factor

    let index 0

    let enterprise-ids table:keys stock-quantity-per-enterprise

    ; el mestre es queda amb la part d'accions que li pertoquen
    while [index < table:length stock-quantity-per-enterprise] [

      let enterprise-id (item index enterprise-ids)

      table:put stock-quantity-per-enterprise enterprise-id round ((table:get stock-quantity-per-enterprise enterprise-id) * coalition-stock-factor)

      set index (index + 1)
    ]

    ; es fa públic el trencament de la coalició
    print (word self " and " coalition-subordinate " have broken their coalition.")

    ask coalition-subordinate [

      set is-in-coalition false
    ]

    set is-in-coalition false

    set is-coalition-master false

    set coalition-subordinate nobody
  ]
end

; Atura la negociació actual
to stop-current-negotiation

  set is-negotiating false
  set is-waiting-for-response false
  set has-buyer-role false
  set current-negotiator nobody

end




to swap-messages
  ask turtles [
    set current-messages next-messages
    set next-messages []
  ]
end


; Fa que els agents processin els missatges que han rebut durant el darrer tick
to process-messages

  ask turtles [

    ; només les empreses i els especuladors no subordinats a coalicions (els mestres sí) poden processar missatges
    if breed != speculators or not is-in-coalition or is-coalition-master [

      ; si l'agent està esperant un missatge cal preveure que trigarà un torn en arribar,
      ; ja que l'altre agent necessita un tick per processar-lo i generar la resposta, de
      ; manera que s'ignoren els missatges actuals
      ifelse is-waiting-for-response [

        ; el següent tick ja sí que es voldrà veure si ha arribat la resposta que s'estava esperant
        set is-waiting-for-response false
      ]

      ; si no cal esperar, s'atenen els missatges actuals
      [

        set has-negotiation-progressed false

        let index 0

        ; s'examinen els missatges fins que un suposi un progrés en una negociació, o fins que s'acabin tots
        while [not has-negotiation-progressed and index < length current-messages] [

          let message item index current-messages

          process-message (item 0 message) (item 1 message) (item 2 message)

          set index (index + 1)
        ]


        ; si en cap dels missatges processats s'ha donat peu a poder progressar amb la negociació actual,
        ; aquesta es considera acabada (també, de tant en tant, es talla arbitràriament una negociació)
        if not has-negotiation-progressed or 3 > random 200 [

          stop-current-negotiation
        ]
      ]
    ]
  ]
end


; Processa un missatge concret que ha rebut un agent
to process-message [sender kind message]

  ; no es processen missatges d'agents inexistents
  if sender != nobody [

    ; es mostra el missatge rebut
    if show-protocol-messages [

      print (word sender " -> " self  ": " kind " " message)
    ]

    let can-process-message true

    ; si es té una negociació en marxa només s'atendran missatges de l'agent amb qui s'està negociant
    if is-negotiating [

      set can-process-message (sender = current-negotiator)
    ]

    ; si es pot atendre el missatge
    if can-process-message [

      ; si ja s'estava negociant
      ifelse is-negotiating [

        ; si a la negociació s'actua com a comprador
        ifelse has-buyer-role [

          ; si s'ha rebut una oferta de venda
          if kind = offer [

            ; es processa l'oferta
            process-sell-offer sender message
          ]
        ]

        ; si a la negociació s'actua com a venedor
        [

          ; si s'ha rebut una proposta de compra
          if kind = propose [

            ; es processa la proposta
            process-buy-proposal sender message
          ]
        ]
      ]

      ; si l'agent no estava negociant
      [

        ; si s'ha rebut una proposta de compra
        ifelse kind = propose [

          ; es processa la proposta
          process-buy-proposal sender message
        ]


        [
          ; si s'ha rebut una oferta de venda
          ifelse kind = offer [

            ; es processa l'oferta
            process-sell-offer sender message
          ]

          [
            ; si s'ha rebut una sol·licitud d'unió en coalició
            if kind = request-for-coalition [

             ; es processa la petició
             process-colation-request sender message
            ]
          ]
        ]
      ]
    ]
  ]

end




; Processa una proposta de compra d'accions que fa un altre agent perquè se li venguin
to process-buy-proposal [potential-buyer proposal]

  ; per acceptar negociar una venda, cal que l'agent sigui un especulador o bé una empresa negociant sobre les seves accions
  if breed = speculators or (item 0 proposal) = who [

    negotiate-to-sell potential-buyer proposal
  ]

end


; Processa una oferta de venda d'accions que fa un altre agent perquè se li comprin
to process-sell-offer [potential-seller sell-offer]

  ; només els especuladors compren accions, no les empreses
  if breed = speculators [

    let has-enough-money false

    ifelse breed = speculators [

      set has-enough-money (money >= min-money-speculator)
    ]

    [
      set has-enough-money (money >= min-money-enterprise)
    ]


    ; si es té un mínim de diners, es negocia una compra
    if has-enough-money [

      negotiate-to-buy potential-seller sell-offer
    ]
  ]

end



; Processa una proposta d'un altre agent de subordinar-se a l'especulador en una coalició
to process-colation-request [applicant request-terms]

  ; si l'agent és un especulador que no forma part d'una coalició ja existent
  if breed = speculators and not is-in-coalition [

   let is-applicant-speculator false

    ask applicant [

     set is-applicant-speculator breed = speculators
    ]

    ; l'altre agent ha de ser també especulador
    if is-applicant-speculator [

      ; es basa la probabilitat d'acceptar en el coeficient de cooperació de l'agent
      let accept-coalition-probability cooperation-coefficient

      ; la probabilitat augmenta en situacions d'un cert bloqueig per l'agent (com tenir un valor estimat en accions molt gran però
      ; pocs diners)
      set accept-coalition-probability 0.1 * (accept-coalition-probability * min (list 0.5 (max (list 3 (get-stock-estimated-value /( money + 0.01))))))

      ; s'accepta o no en base a probabilitats
      if accept-coalition-probability * 100 >= random 100 [

        ; es forma la coalició
        make-coalition applicant request-terms
      ]
    ]
  ]

end


; Envia un missatge al receptor passat per paràmetre, del tipus indicat i amb el contingut de missatge passat
to send-message [recipient kind message]

  ; no té sentit enviar-se un missatge a un mateix
  if recipient != self [

    ; afegim el missatge a la cua de missatges de l'agent receptor
    ; (s'afegeix a next-messages perquè el receptor no ho vegi fins la propera iteració
    ask recipient [
      set next-messages lput (list myself kind message) next-messages
    ]
  ]
end


; Controla el fet de mostrar dades estadístiques de forma periòdica
to manage-statistics

  ; mostra dades estadístiques periòdicament
  ifelse ticks-since-statistics > ticks-to-show-statistics [

    print "\n\n\n\n\nBATCH OF STATISTICS:\n"

    ask turtles [

      show-statistics
    ]

    print (word "total market money: " market-money)

    set ticks-since-statistics 0
  ]

  [
    set ticks-since-statistics (ticks-since-statistics + 1)
  ]
end



; Mostra dades estadístiques sobre l'agent
to show-statistics

  ; s'ignoren els subordinats de coalicions
  if breed = speculators and is-in-coalition and not is-coalition-master [

    stop
  ]

  print (word self " has lived for " (ticks - start-tick) " ticks:\n\tstart money: " start-money "; current money: " money "; best moment money: " best-moment-money
    "\n\ttransaction num: " transaction-num " (purchases: " (transaction-num - sales-num) "; sales: " sales-num ")")

  ifelse breed = speculators [

   print (word "\trisk coefficient: " risk-coefficient)

    if is-coalition-master [

     print (word "\tis the master of a coalition with " coalition-subordinate)
    ]
  ]

  [

   if breed = enterprises [

     print (word "\t high price coefficient " high-price-coefficient)
    ]
  ]

  print "\n\n"

end




to update-color

  ; el color no s'actualitza per a subordinats de coalicions
  if breed = speculators and is-in-coalition and not is-coalition-master [

   stop
  ]

  let reference-money max-money-speculator

  if breed = enterprises [

    set reference-money max-money-enterprise * 1.05
  ]

  let color-intensity 55 + ((money / (1.3 * reference-money)) * 200 * color-multiplier)

  ; límit en el valor de color
  if color-intensity > 255 [
    set color-intensity 255
  ]
  if color-intensity < 0[
    set color-intensity 0
  ]

  ; el color passa de vermell a verd en funció dels diners
  set color (list (255 - color-intensity) color-intensity  0)



end
@#$#@#$#@
GRAPHICS-WINDOW
13
35
423
446
-1
-1
12.2
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
345
534
411
567
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
347
580
410
613
Run
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
34
588
234
621
min-money-speculator
min-money-speculator
0
1000
500.0
100
1
NIL
HORIZONTAL

SLIDER
34
634
232
667
max-money-speculator
max-money-speculator
1000
5000
2000.0
100
1
NIL
HORIZONTAL

SLIDER
28
795
234
828
min-risk-coefficient
min-risk-coefficient
0
.5
0.25
0.01
1
NIL
HORIZONTAL

SLIDER
30
843
234
876
max-risk-coefficient
max-risk-coefficient
.5
1
0.75
.01
1
NIL
HORIZONTAL

SLIDER
34
538
206
571
speculator-num
speculator-num
0
20
20.0
1
1
NIL
HORIZONTAL

SLIDER
1020
704
1192
737
enterprise-num
enterprise-num
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
1020
753
1226
786
min-money-enterprise
min-money-enterprise
0
10000
5000.0
100
1
NIL
HORIZONTAL

SLIDER
1020
795
1228
828
max-money-enterprise
max-money-enterprise
10000
100000
45000.0
1000
1
NIL
HORIZONTAL

SLIDER
1251
753
1489
786
min-high-price-coefficient
min-high-price-coefficient
0
.5
0.25
.01
1
NIL
HORIZONTAL

SLIDER
1254
798
1495
831
max-high-price-coefficient
max-high-price-coefficient
.5
1
0.75
.01
1
NIL
HORIZONTAL

SLIDER
1622
747
1794
780
color-multiplier
color-multiplier
0
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
35
693
250
726
min-perception-radius
min-perception-radius
3
10
6.0
1
1
NIL
HORIZONTAL

SLIDER
35
744
253
777
max-perception-radius
max-perception-radius
10
30
20.0
1
1
NIL
HORIZONTAL

SWITCH
1624
799
1851
832
show-protocol-messages
show-protocol-messages
1
1
-1000

SLIDER
641
809
813
842
transaction-tax
transaction-tax
0.1
1
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
643
700
872
733
raffle-participation-money
raffle-participation-money
0.01
0.1
0.01
0.01
1
NIL
HORIZONTAL

SLIDER
642
753
868
786
win-raffle-probability
win-raffle-probability
0.000001
0.0001
2.0E-5
0.000001
1
NIL
HORIZONTAL

PLOT
488
500
928
640
Speculators' money standard deviation
Time (ticks)
Deviation
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"std dev." 1.0 0 -16777216 true "" "plot get-speculators-money-standard-deviation"

PLOT
958
498
1378
643
Enterprises' money standard deviation
Time (ticks)
Deviation
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"std dev." 1.0 0 -16777216 true "" "plot get-enterprises-money-standard-deviation"

PLOT
481
14
923
159
Speculators' average money
Time (ticks)
Money
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"richest" 1.0 0 -11085214 true "" "plot get-money-of-richest-speculator"
"average" 1.0 0 -14737633 true "" "plot get-speculators-average-money"
"poorest" 1.0 0 -2674135 true "" "plot get-money-of-poorest-speculator"

PLOT
956
14
1379
160
Enterprises' average money
Time (ticks)
Money
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"richest" 1.0 0 -11085214 true "" "plot get-money-of-richest-enterprise"
"average" 1.0 0 -14737633 true "" "plot get-enterprises-average-money"
"poorest" 1.0 0 -2674135 true "" "plot get-money-of-poorest-enterprise"

PLOT
482
171
922
321
Speculators' average money by risk coefficient
Time (ticks)
Money
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"high" 1.0 0 -3844592 true "" "plot get-average-money-of-speculators-with-high-risk-coefficient"
"mid" 1.0 0 -10899396 true "" "plot get-average-money-of-speculators-with-intermediate-risk-coefficient"
"low" 1.0 0 -13791810 true "" "plot get-average-money-of-speculators-with-low-risk-coefficient"

PLOT
955
171
1415
321
Enterprises' average money by high-price coefficient
Time (ticks)
Money
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"high" 1.0 0 -3844592 true "" "plot get-average-money-of-enterprises-with-high-high-price-coefficient"
"mid" 1.0 0 -14439633 true "" "plot get-average-money-of-enterprises-with-intermediate-high-price-coefficient"
"low" 1.0 0 -13791810 true "" "plot get-average-money-of-enterprises-with-low-high-price-coefficient"

PLOT
481
335
927
485
Speculators' average money by start money
Time (ticks)
Money
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"rich" 1.0 0 -13840069 true "" "plot get-average-money-of-initially-rich-speculators"
"standard" 1.0 0 -4079321 true "" "plot get-average-money-of-initially-standard-speculators"
"poor" 1.0 0 -2674135 true "" "plot get-average-money-of-initially-poor-speculators"

PLOT
953
334
1414
484
Enterprises' average money by start money
Time (ticks)
Money
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"rich" 1.0 0 -13840069 true "" "plot get-average-money-of-initially-rich-enterprises"
"standard" 1.0 0 -4079321 true "" "plot get-average-money-of-initially-standard-enterprises"
"poor" 1.0 0 -2674135 true "" "plot get-average-money-of-initially-poor-enterprises"

PLOT
1463
10
1983
206
Stock average value estimation
Time (ticks)
Money / stock unit
0.0
10.0
0.0
2.0
true
true
"" ""
PENS
"speculators' average" 1.0 0 -8630108 true "" "plot get-speculators-stock-average-value-estimation"
"enterprises' average" 1.0 0 -13345367 true "" "plot get-enterprises-stock-average-value-estimation"
"market average" 1.0 0 -14835848 true "" "plot get-market-stock-average-value-estimation"
"1 (reference)" 1.0 0 -3026479 true "" "plot 1"

PLOT
1462
230
1721
398
Market money
Time (ticks)
Money
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"market money" 1.0 0 -16777216 true "" "plot market-money"

SLIDER
307
747
599
780
request-coalition-probability-factor
request-coalition-probability-factor
0
0.02
0.005
0.001
1
NIL
HORIZONTAL

PLOT
1459
414
1702
534
Speculator coalitions number
Time (ticks)
Num
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"coalition number" 1.0 0 -16777216 true "" "plot 0.5 * count speculators with [is-in-coalition]"

SLIDER
305
794
563
827
min-cooperation-coefficient
min-cooperation-coefficient
0
0.3
0.15
0.05
1
NIL
HORIZONTAL

SLIDER
303
844
561
877
max-cooperation-coefficient
max-cooperation-coefficient
0.3
0.6
0.45
0.05
1
NIL
HORIZONTAL

PLOT
1747
230
1987
399
Market transactions
Time (ticks)
Number
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"transactions" 1.0 0 -16777216 true "" "plot get-market-transaction-num"

PLOT
1460
553
1887
690
Coalitions average money
Time (ticks)
Money
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"speculators average" 1.0 0 -2570826 true "" "plot get-speculators-average-money"
"coalitions average" 1.0 0 -5987164 true "" "plot get-speculator-coalitions-average-money"
"coalition members average" 1.0 0 -16777216 true "" "plot get-speculator-coalitions-average-money / 2"

SWITCH
307
695
519
728
are-coalitions-allowed
are-coalitions-allowed
0
1
-1000

TEXTBOX
146
12
340
64
Financial market
20
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

house colonial
false
0
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 45 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 60 195 105 240
Rectangle -16777216 true false 60 150 105 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Polygon -7500403 true true 30 135 285 135 240 90 75 90
Line -16777216 false 30 135 285 135
Line -16777216 false 255 105 285 135
Line -7500403 true 154 195 154 255
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 135 150 180 180

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
