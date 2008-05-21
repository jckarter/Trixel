USING: accessors destructors kernel trixel.resource-cache ;
IN: trixel.resource-cache.mock

TUPLE: mock-resource name ;

M: mock-resource load-resource ( resource name -- resource ) >>name ;
M: mock-resource dispose ( resource -- ) drop ;

