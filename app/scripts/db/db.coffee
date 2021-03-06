###
  Angular wrapper for datavore.js

  app_database module serves as the in-memory database for SOCR framework. The module lets
  you perform create, read, update and delete operations on all the tables created by the
  application.

  "database" service is the single point access for all the CRUD operations.To make DB calls
  from another module, publish messages using the "sb" object.

  Notes:
    Datavore doesnt have inbuilt event system
    or memory of the tables created using it.
###

db = angular.module 'app_database', []


db.factory 'app_database_constructor', [
  'app_database_manager'
  (manager) ->
    (sb) ->

      manager.setSb sb unless !sb?
      _msgList = manager.getMsgList()

      init: (opt) ->
        console.log '%cDATABASE:: init called', 'color:green'

      destroy: ->

      msgList: _msgList
]

db.factory 'app_database_manager', [
  'app_database_handler'
  (database) ->
    _sb = null
    #_msgList =
    #  incoming:['create table','get table','delete table'],
    #  outgoing:['table created','take table','table deleted'],
    #  scope: ['database']

    _msgList =
      incoming: ['save table','create table', 'get table', 'delete table']
      outgoing: ['table saved','table created', 'take table', 'table deleted']
      scope: ['database']

    _setSb = (sb) ->
      _sb = sb
      database.setSb sb

    _getSb = ->
      _sb

    _getMsgList = ->
      _msgList

    getSb: _getSb
    setSb: _setSb
    getMsgList: _getMsgList
]

# ###
# @name: app_database_dataFrame2table
# @type: factory
# @description: Reformats data from the universal dataFrame object to datavore format
# ###
db.factory 'app_database_dataAdaptor', [
  () ->

    _toDvTable = (dataFrame) ->

      table = []

      # transpose array to make it column oriented
      _data = ((row[i] for row in dataFrame.data) for i in [0...dataFrame.nCols])

      for i, col of _data
        table.push
          name: dataFrame.header[i]
          values: col
          type: 'symbolic'

      table

    _toDataFrame = (table) ->

      _nRows = table[0].length
      _nCols = table.length

      # transpose array to make it row oriented
      _data = ((col[i] for col in table) for i in [0..._nRows])

      _header = (col.name for col in table)
      _types = (col.type for col in table)

      dataFrame =
        data: _data
        header: _header
        types: _types
        nRows: _nRows
        nCols: _nCols

    toDvTable: _toDvTable
    toDataFrame: _toDataFrame
]

db.service 'app_database_dv', ->

  # contains references to all the tables created.
  _registry = []
  _listeners = {}
  _db = {}
  window._db = _db

  ###
    @returns {string|boolean}
  ###
  _register = (tname, ref) ->
    return false if _registry[tname]?
    # #name already exists. Create an alternate name.
    #   tname = '_' + tname
    #   _register tname,ref
    _registry[tname] = ref
    tname

  _fire = (tname, cname)->

    if typeof _registry[tname] isnt 'undefined' && typeof _listeners[tname] isnt 'undefined'
      _table = _listeners[tname]
    else
      return false

    #trigger all listeners attached to the column `name`

    if cname? && typeof _table[cname] isnt 'undefined'
      i = 0
      while i < _table[cname].cb.length
        _table[cname].cb[i] _registry[tname][cname] if typeof _table[cname].cb[i] is 'function'
        i++

    #trigger all listeners attached to the table.
    #console.log _l?.length
    if _table.cb?.length isnt 0
      i = 0
      while i < _table.cb.length
        _table.cb[i] _registry[tname] if typeof _table.cb[i] is 'function'
        i++

  _db.create = (input, tname) ->

    # TODO: separate updating from creating
    if _registry[tname]?
      _db.update input, tname
    else

      # reformat data type
      for col in input
        switch col.type
          when 'numeric' then col.type = dv.type.numeric
          when 'nominal' then col.type = dv.type.nominal
          when 'ordinal' then col.type = dv.type.ordinal
          else col.type = dv.type.unknown

      # create table
      _ref = dv.table input
      # register the reference to the table
      _register tname, _ref
      _db

  _db.update = (input, tname) ->
    # delete old table
    _db.destroy tname
    # create new table
    _db.create input, tname

  _db.addColumn = (cname, values, type, iscolumn..., tname)->
    if _registry[tname]?
      _registry[tname].addColumn cname, values, type, iscolumn
      #fire away all listeners on the new column.

      _fire tname, cname

  _db.removeColumn = (cname, tname) ->
    if _registry[tname]?[cname]?
      #fire away all listeners on the new column.
      _fire tname, cname
      delete _registry[tname][cname]
      true
    else
      false

  _db.addListener = (opts) ->
    if opts?
      if typeof opts is 'function'
        return false
      else
        if opts.table?
          _listeners[opts.table] = _listeners[opts.table] || {cb: []}
          if opts.column?
            _listeners[opts.table][opts.column] = _listeners[opts.table][opts.column] || {cb: []}
            _listeners[opts.table][opts.column]['cb'].push opts.listener
          else
            _listeners[opts.table]['cb'].push opts.listener
    console.log '%cDATABASE:: listeners:', 'color:green'
    console.log _listeners[opts.table]

  # destroy any table
  _db.destroy = (tname) ->
    if _registry[tname]?
      delete _registry[tname]
      true
    else
      false

  _db.rows = (tname) ->
    if _registry[tname]?
      _registry[tname].rows()

  _db.cols = (tname) ->
    if _registry[tname]?
      _registry[tname].cols()

  _db.get = (tname, col, row) ->
    if _registry[tname]?
      if col?
        if row?
          _registry[tname][col].get row
        else
          _registry[tname][col]
      else
        _registry[tname]
    else
      false

  _db.exists = (tname) ->
    if _registry[tname]?
      true
    else
      false

  # Query methods
  _db.query = (q, name) ->
    _db.dense_query(q, name)

  _db.dense_query = (q, tname) ->
    if _registry[tname]?
      _registry[tname].dense_query(q)

  _db.sparse_query = (q, tname) ->
    if _registry[tname]?
      _registry[tname].sparse_query(q)

  _db.where = (q, tname) ->
    if _registry[tname]?
      _registry[tname].where(q)

  _db


db.factory 'app_database_handler', [
  '$q'
  'app_database_dv'
  'app_database_dataAdaptor'
  ($q, _db, dataAdaptor) ->

    # set all the callbacks here.
    _setSb = ((_db) ->
      window.db = _db
      (sb) ->

        #registering database callbacks for all possible incoming messages.
        # TODO: add wrapper layer on top of _db methods?
        _methods = [
          {incoming: 'save table', outgoing: 'table saved', event: _db.create}
          {incoming: 'get table', outgoing: 'take table', event: _db.get}
          {incoming: 'add listener', outgoing: 'listener added', event: _db.addListener}
        ]

        _status = _methods.map (method) ->
          sb.subscribe
            msg: method['incoming']
            msgScope: ['database']
            listener: (msg, data) ->
              console.log "%cDATABASE: listener called for"+msg , "color:green"

              # convert from the universal dataFrame object to datavore table
              dvTableData = if msg is 'save table' then dataAdaptor.toDvTable data.dataFrame else data

              # arrange arguments for a callback
              # @todo need to find a better way for this.
              _data = switch
                when msg is 'save table' then [ dvTableData, data.tableName ]
                when msg is 'get table' then [ data.tableName ]
                else data

              # invoke callback
              _data = method.event.apply null, _data

              # convert data to DataFrame if returning it
              _data = dataAdaptor.toDataFrame _data if msg is 'get table'

              # all publish calls should pass a promise in the data object
              # if promise is not defined, create one and pass it along
              deferred = data.promise
              if typeof deferred isnt 'undefined'
                if _data isnt false then deferred.resolve() else deferred.reject()
              else
                _data.promise = $q.defer()

              console.log '%cDATABASE: listener response: ' + _data, 'color:green'

              sb.publish
                msg: method.outgoing
                data: _data
                msgScope: ['database']
    )(_db)

    setSb: _setSb
  ]
