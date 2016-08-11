'use strict'

BaseCtrl = require 'scripts/BaseClasses/BaseController.coffee'

module.exports = class ClusterMainCtrl extends BaseCtrl
  @inject 'app_analysis_cluster_dataService'

  initialize: ->
    @dataService = @app_analysis_cluster_dataService
    @title = 'Clustering module'
    @dataType = ''
    @transforming = off
    @transformation = ''
    @transformations = []
    @affinityMatrix = null
    @data_types = @dataService.getDataTypes()
    @getData()

  getData: ->
    @dataService.getData().then (obj) =>
      @dataType = obj.dataFrame.dataType
      # TODO: main controller logic