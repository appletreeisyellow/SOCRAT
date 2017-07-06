'use strict'

BaseService = require 'scripts/BaseClasses/BaseService.coffee'

###
  @name: app_analysis_powercalc_oneTest
  @type: service
  @desc: Performs one sample t test analysis
###


module.exports = class PowerCalc_OneTGUI extends BaseService
  @inject 'app_analysis_powercalc_msgService',
    '$timeout'

   initialize: ->
    @distanceFromMean = 5
    @SIGNIFICANT = 5
    @populations = null
    @distribution = require 'distributome'
    @msgService = @app_analysis_powercalc_msgService
    @name = 'One-Sample (or Paired) t Test'
    #variables needed for One-sample t test
    @oneTestn = 10
    @oneTestnMax = 20
    @oneTestmean = 10
    @oneTestmeanMax = 20
    @oneTestmean0 = 10
    @oneTestmean0Max = 20
    @oneTestsigma = 10
    @oneTestsigmaMax = 20
    @oneTestpower = 0
    @oneTestalpha = 0.010
    @oneTestvariance = 0
    @oneTestt = 0
    @oneTestpvalue = 0
    @comp_agents = []
    @oneTestmode = "Two Tailed"
    @oneTestmodes = ["Two Tailed", "One Tailed"]

    #data to observe
    @parameters =
      n: @oneTestn
      nMax: @oneTestnMax
      mean: @oneTestmean
      mean0: @oneTestmean0
      meanMax: @oneTestmeanMax
      mean0Max: @oneTestmean0Max
      sigma: @oneTestsigma
      sigmaMax: @oneTestsigmaMax
      power: @oneTestpower
      t: @oneTestt
      pvl: @oneTestpvalue
      comp: @comp_agents
      mode: @oneTestmode

    @oneTestUpdate()

  saveData: (data) ->
    @populations = data.populations
    lab = data.chosenlab
    if (lab is "none") or (lab is null)
      @comp_agents = data.chosenCol
    else
      @comp_agents = data.chosenVar
    @oneTestReceiveData()

  setAlpha: (alphaIn) ->
    @oneTestalpha = alphaIn
    @oneTestUpdate()
    @oneTestCheckRange()
    return

  getName: () ->
    return @name

  getParams: () ->
    @parameters =
      n: @oneTestn
      nMax: @oneTestnMax
      mean: @oneTestmean
      mean0: @oneTestmean0
      meanMax: @oneTestmeanMax
      mean0Max: @oneTestmean0Max
      sigma: @oneTestsigma
      sigmaMax: @oneTestsigmaMax
      power: @oneTestpower
      t: @oneTestt
      pvl: @oneTestpvalue
      comp: @comp_agents
      mode: @oneTestmode

  setParams: (newParams) ->
    @oneTestn = newParams.n
    @oneTestmean = newParams.mean
    @oneTestmean0 = newParams.mean0
    @oneTestsigma = newParams.sigma
    @oneTestpower = newParams.power
    @oneTestmode = newParams.mode
    @oneTestUpdate()
    return

  savePower: (newParams) ->
    @oneTestpower = newParams.power
    @oneTestmode = newParams.mode
    @oneTestPowerTon()
    return

  reset: () ->
    @oneTestn = 10
    @oneTestnMax = 20
    @oneTestmean = 10
    @oneTestmeanMax = 20
    @oneTestmean0 = 10
    @oneTestmean0Max = 20
    @oneTestsigma = 40
    @oneTestsigmaMax = 60
    @oneTestpower = 0
    @oneTestalpha = 0.010
    @oneTestvariance = 0
    @oneTestt = 0
    @oneTestpvalue = 0
    @comp_agents = []
    @oneTestmode = "Two Tailed"
    @oneTestUpdate()
    return

  oneTestReceiveData: () ->
    item = Object.keys(@populations)[0]
    @oneTestn = @populations[item].length
    @oneTestmean = @getMean(@getSum(@populations[item]),@populations[item].length)
    @oneTestvariance = @getVariance(@populations[item], @oneTestmean)
    @oneTestsigma = Math.sqrt(@oneTestvariance)
    @oneTestCheckRange()
    @oneTestUpdate()
    return

  oneTestCheckRange:() ->
    @oneTestnMax = Math.max(@oneTestn, @oneTestmeanMax)
    @oneTestmeanMax = Math.max(@oneTestmean, @oneTestmeanMax, @oneTestmean0Max)
    @oneTestmean0Max = @oneTestmeanMax
    @oneTestsigmaMax = Math.max(@oneTestsigma, @oneTestsigmaMax)
    return

  oneTestUpdate: () ->
    z = (@oneTestmean - @oneTestmean0)/ (@oneTestsigma * Math.sqrt(@oneTestn))
    if @oneTestmode is "Two Tailed"
      @oneTestpower=@distribution.pnorm(z-@distribution.qnorm(1-@oneTestalpha/2))+@distribution.pnorm(-z-@distribution.qnorm(1-@oneTestalpha/2))
    else
      @oneTestpower=@distribution.pnorm(Math.abs(z)-@distribution.qnorm(1-@oneTestalpha))
    @oneTestTTest()
    @oneTestCheckRange()
    return

  oneTestPowerTon: () ->
    # calculate n1 or n2 from power based on different mdoes
    if @oneTestmode is "Two Tailed"
      @oneTestn = Math.pow(@oneTestsigma * (@distribution.qnorm(1-@oneTestalpha / 2) + @distribution.qnorm(@oneTestpower))/(@oneTestmean-@oneTestmean0),2)
    else
      @oneTestn = Math.pow(@oneTestsigma * (@distribution.qnorm(1-@oneTestalpha) + @distribution.qnorm(@oneTestalpha))/(@oneTestmean-@oneTestmean0), 2)
      @oneTestn = Math.ceil(@oneTestn)
    @oneTestCheckRange()
    return

  oneTestTTest: () ->
    df = @oneTestn - 1
    @oneTestt = @tdistr(df, 1 - @oneTestalpha)
    @oneTestpvalue = @tprob(df, @oneTestt)

  getRightBound: (middle,step) ->
    return middle + step * @distanceFromMean

  getLeftBound: (middle,step) ->
    return middle - step * @distanceFromMean

  getVariance: (values, mean) ->
    temp = 0
    numberOfValues = values.length
    while( numberOfValues--)
      temp += Math.pow( (parseInt(values[numberOfValues]) - mean), 2 )
    return temp / values.length

  getSum: (values) ->
    values.reduce (previousValue, currentValue) -> parseFloat(previousValue) + parseFloat(currentValue)

  getGaussianFunctionPoints: (mean, std, leftBound, rightBound) ->
    data = []
    for i in [leftBound...rightBound]
      data.push
        x: i
        y: (1 / (std * Math.sqrt(Math.PI * 2))) * Math.exp(-(Math.pow(i - mean, 2) / (2 * Math.pow(std, 2))))
    data

  getMean: (valueSum, numberOfOccurrences) ->
    valueSum / numberOfOccurrences

  getChartData: () ->
    mean = @oneTestmean
    stdDev = @oneTestsigma
    alpha = @oneTestalpha

    rightBound = @getRightBound(mean, stdDev)
    leftBound =  @getLeftBound(mean, stdDev)
    bottomBound = 0
    topBound = 1 / (stdDev * Math.sqrt(Math.PI * 2))
    gaussianCurveData = @getGaussianFunctionPoints(mean, stdDev, leftBound, rightBound)

    bounds =
      left: leftBound
      right: rightBound
      top: topBound
      bottom: bottomBound

    data = [gaussianCurveData]

    return {
      data: data
      bounds: bounds
    }

  tprob: ($n, $x) ->
    if $n <= 0
      throw 'Invalid n: $n\n'
      ### degree of freedom ###
    @precisionString @subtprob($n - 0, $x - 0)
  integer: ($i) ->
    if $i > 0
      Math.floor $i
    else
      Math.ceil $i
  precisionString: ($x) ->
    if $x
      @roundToPrecision $x, @precision($x)
    else
      '0'
  roundToPrecision: ($x, $p) ->
    $x = $x * 10 ** $p
    $x = Math.round($x)
    $x / 10 ** $p
  precision: ($x) ->
    Math.abs @integer(@log10(Math.abs($x)) - @SIGNIFICANT)
  subtprob: ($n, $x) ->
    $a = undefined
    $b = undefined
    $w = Math.atan2($x / Math.sqrt($n), 1)
    $z = Math.cos($w) ** 2
    $y = 1
    $i = $n - 2
    while $i >= 2
      $y = 1 + ($i - 1) / $i * $z * $y
      $i -= 2
    if $n % 2 == 0
      $a = Math.sin($w) / 2
      $b = .5
    else
      $a = if $n == 1 then 0 else Math.sin($w) * Math.cos($w) / Math.PI
      $b = .5 + $w / Math.PI
    @max 0, 1 - $b - ($a * $y)

  log10: ($n) ->
    Math.log($n) / Math.log(10)
  max: () ->
    $max = arguments[0]
    $i = 0
    while $i < arguments.length
      if $max < arguments[$i]
        $max = arguments[$i]
      $i++
    $max
  tdistr: ($n, $p) ->
    if $n <= 0
      throw 'Invalid n: $n\n'
    if $p <= 0 or $p >= 1
      throw 'Invalid p: $p\n'
    @precisionString @subt($n - 0, $p - 0)
  subt: ($n, $p) ->
    if $p >= 1 or $p <= 0
      throw 'Invalid p: $p\n'
    if $p == 0.5
      return 0
    else if $p < 0.5
      return -@subt($n, 1 - $p)
    $u = @subu($p)
    $u2 = $u ** 2
    $a = ($u2 + 1) / 4
    $b = ((5 * $u2 + 16) * $u2 + 3) / 96
    $c = (((3 * $u2 + 19) * $u2 + 17) * $u2 - 15) / 384
    $d = ((((79 * $u2 + 776) * $u2 + 1482) * $u2 - 1920) * $u2 - 945) / 92160
    $e = (((((27 * $u2 + 339) * $u2 + 930) * $u2 - 1782) * $u2 - 765) * $u2 + 17955) / 368640
    $x = $u * (1 + ($a + ($b + ($c + ($d + $e / $n) / $n) / $n) / $n) / $n)
    if $n <= @log10($p) ** 2 + 3
      $round = undefined
      loop
        $p1 = @subtprob($n, $x)
        $n1 = $n + 1
        $delta = ($p1 - $p) / Math.exp(($n1 * Math.log($n1 / ($n + $x * $x)) + Math.log($n / $n1 / 2 / Math.PI) - 1 + (1 / $n1 - (1 / $n)) / 6) / 2)
        $x += $delta
        $round = @roundToPrecision($delta, Math.abs(@integer(@log10(Math.abs($x)) - 4)))
        unless $x and $round != 0
          break
    $x
  subu: ($p) ->
    $y = -Math.log(4 * $p * (1 - $p))
    $x = Math.sqrt($y * (1.570796288 + $y * (.03706987906 + $y * (-.8364353589e-3 + $y * (-.2250947176e-3 + $y * (.6841218299e-5 + $y * (0.5824238515e-5 + $y * (-.104527497e-5 + $y * (.8360937017e-7 + $y * (-.3231081277e-8 + $y * (.3657763036e-10 + $y * .6936233982e-12)))))))))))
    if $p > .5
      $x = -$x
    $x
