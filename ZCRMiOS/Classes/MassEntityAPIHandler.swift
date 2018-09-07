//
//  MassEntityAPIHandler.swift
//  ZCRMiOS
//
//  Created by Vijayakrishna on 16/11/16.
//  Copyright © 2016 zohocrm. All rights reserved.
//

internal class MassEntityAPIHandler : CommonAPIHandler
{
	private var module : ZCRMModule
    private var trashRecord : ZCRMTrashRecord = ZCRMTrashRecord( type : "" )
	
	init(module : ZCRMModule)
	{
		self.module = module
	}
	
	// MARK: - Handler Functions
    
    internal func createRecords( records : [ ZCRMRecord ], completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        setJSONRootKey( key : JSONRootKey.DATA )
        if(records.count > 100)
        {
            completion( nil, nil, ZCRMError.MaxRecordCountExceeded( code : MAX_COUNT_EXCEEDED, message : "Cannot process more than 100 records at a time." ) )
        }
        var reqBodyObj : [String:[[String:Any]]] = [String:[[String:Any]]]()
        var dataArray : [[String:Any]] = [[String:Any]]()
        for record in records
        {
            dataArray.append(EntityAPIHandler(record: record).getZCRMRecordAsJSON() as Any as! [String : Any])
        }
        reqBodyObj[getJSONRootKey()] = dataArray
		
		setUrlPath(urlPath :  "/\(self.module.getAPIName())" )
		setRequestMethod(requestMethod : .POST )
		setRequestBody(requestBody : reqBodyObj )
		let request : APIRequest = APIRequest(handler: self )
        print( "Request : \( request.toString() )" )
        
        request.getBulkAPIResponse { ( response, err ) in
            if let error = err
            {
                completion( nil, nil, error )
                return
            }
            if let bulkResponse = response
            {
                let responses : [EntityResponse] = bulkResponse.getEntityResponses()
                var updatedRecords : [ZCRMRecord] = [ZCRMRecord]()
                for entityResponse in responses
                {
                    if(CODE_SUCCESS == entityResponse.getStatus())
                    {
                        let entResponseJSON : [String:Any] = entityResponse.getResponseJSON()
                        let recordJSON : [String:Any] = entResponseJSON.getDictionary(key: DETAILS)
                        let record : ZCRMRecord = ZCRMRecord(moduleAPIName: self.module.getAPIName(), recordId: recordJSON.getInt64(key: ResponseJSONKeys.id))
                        EntityAPIHandler(record: record).setRecordProperties(recordDetails: recordJSON)
                        updatedRecords.append(record)
                        entityResponse.setData(data: record)
                    }
                    else
                    {
                        entityResponse.setData(data: nil)
                    }
                }
                bulkResponse.setData( data : updatedRecords )
                completion( updatedRecords, bulkResponse, nil )
            }
        }
    }
	
    internal func getRecords(cvId : Int64? ,fields : [String]? ,  sortByField : String? , sortOrder : SortOrder? , converted : Bool? , approved : Bool? , page : Int , per_page : Int , modifiedSince : String?, includePrivateFields : Bool, kanbanView : String?, completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
	{
        setJSONRootKey( key : JSONRootKey.DATA )
		var records : [ZCRMRecord] = [ZCRMRecord]()
		setUrlPath(urlPath: "/\(self.module.getAPIName())" )
		setRequestMethod( requestMethod : .GET )
		if ( fields != nil && !fields!.isEmpty)
		{
			
			var fieldsStr : String = ""
			for field in fields!
			{
				if(!field.isEmpty)
				{
					fieldsStr += field + ","
				}
			}
			if(!fieldsStr.isEmpty)
			{
				addRequestParam(param: RequestParamKeys.fields , value: String(fieldsStr.dropLast()) )
			}
			
		}
		if(cvId != nil)
		{
			addRequestParam(param:  "cvid" , value: String(cvId!) )
		}
		if(sortByField.notNilandEmpty)
		{
			addRequestParam(param: "sort_by" , value:  sortByField! )
		}
		if(sortOrder != nil)
		{
			addRequestParam(param: "sort_order" , value: sortOrder!.rawValue )
		}
		if(converted != nil)
		{
			addRequestParam(param: "converted" , value: converted!.description )
		}
		if(approved != nil)
		{
			addRequestParam(param: "approved" , value: approved!.description )
		}
        if ( modifiedSince.notNilandEmpty )
        {
         	addRequestHeader(header: "If-Modified-Since" , value: modifiedSince! )
        }
        if( includePrivateFields == true )
        {
            addRequestParam( param : "include", value : PRIVATE_FIELDS )
        }
        if( kanbanView.notNilandEmpty )
        {
            addRequestParam( param : RequestParamKeys.kanbanView, value : kanbanView! )
        }
		addRequestParam(param: "page" , value: String(page) )
		addRequestParam(param: "per_page" , value: String(per_page) )
		let request : APIRequest = APIRequest(handler: self )
        print( "Request : \( request.toString() )" )
		
        request.getBulkAPIResponse { ( response, err ) in
            if let error = err
            {
                completion( nil, nil, error )
                return
            }
            if let bulkResponse = response
            {
                let responseJSON = bulkResponse.getResponseJSON()
                if responseJSON.isEmpty == false
                {
                    let recordsDetailsList:[[String:Any]] = responseJSON.getArrayOfDictionaries(key: self.getJSONRootKey())
                    for recordDetails in recordsDetailsList
                    {
                        let record : ZCRMRecord = ZCRMRecord(moduleAPIName: self.module.getAPIName(), recordId: recordDetails.getInt64(key: ResponseJSONKeys.id))
                        EntityAPIHandler(record: record).setRecordProperties(recordDetails: recordDetails)
                        records.append(record)
                    }
                    bulkResponse.setData(data: records)
                }
                completion( records, bulkResponse, nil )
            }
        }
		
	}
    
    internal func searchByText( searchText : String, page : Int, perPage : Int, completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        self.searchRecords( searchKey : RequestParamValues.word, searchValue : searchText, page : page, per_page : perPage ) { ( records, response, error ) in
            completion( records, response, error )
        }
    }
    
    internal func searchByCriteria( searchCriteria : String, page : Int, perPage : Int, completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        self.searchRecords( searchKey : RequestParamValues.criteria, searchValue : searchCriteria, page : page, per_page : perPage ) { ( records, response, error ) in
            completion( records, response, error )
        }
    }
    
    internal func searchByEmail( searchValue : String, page : Int, perPage : Int, completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        self.searchRecords( searchKey : RequestParamValues.email, searchValue : searchValue, page : page, per_page : perPage) { ( records, response, error ) in
            completion( records, response, error )
        }
    }
    
    internal func searchByPhone( searchValue : String, page : Int, perPage : Int, completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        self.searchRecords( searchKey : RequestParamValues.phone, searchValue : searchValue, page : page, per_page : perPage) { ( records, response, error ) in
            completion( records, response, error )
        }
    }
	
    private func searchRecords( searchKey : String, searchValue : String, page : Int, per_page : Int, completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
	{
        setJSONRootKey( key : JSONRootKey.DATA )
		var records : [ZCRMRecord] = [ZCRMRecord]()
		setUrlPath(urlPath : "/\(self.module.getAPIName())/search" )
		setRequestMethod(requestMethod : .GET )
		addRequestParam(param:  searchKey , value: searchValue.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
		addRequestParam(param: "page" , value: String(page) )
		addRequestParam(param: "per_page" , value: String(per_page) )
		let request : APIRequest = APIRequest(handler: self )
		
        print( "Request : \( request.toString() )" )
        request.getBulkAPIResponse { ( response, err ) in
            if let error = err
            {
                completion( nil, nil, error )
                return
            }
            if let bulkResponse = response
            {
                let responseJSON = bulkResponse.getResponseJSON()
                if responseJSON.isEmpty == false
                {
                    let recordsList:[[String:Any]] = responseJSON.getArrayOfDictionaries(key: self.getJSONRootKey())
                    for recordDetails in recordsList
                    {
                        let record : ZCRMRecord = ZCRMRecord(moduleAPIName: self.module.getAPIName(), recordId: recordDetails.getInt64(key: ResponseJSONKeys.id))
                        EntityAPIHandler(record: record).setRecordProperties(recordDetails: recordDetails)
                        records.append(record)
                    }
                }
                bulkResponse.setData( data : records )
                completion( records, bulkResponse, nil )
            }
        }
	}
	
    internal func updateRecords( ids : [ Int64 ], fieldAPIName : String, value : Any?, completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
	{
        setJSONRootKey( key : JSONRootKey.DATA )
        if(ids.count > 100)
        {
            completion( nil, nil, ZCRMError.MaxRecordCountExceeded( code : MAX_COUNT_EXCEEDED, message : "Cannot process more than 100 records at a time.") )
        }
		var reqBodyObj : [String:[[String:Any]]] = [String:[[String:Any]]]()
		var dataArray : [[String:Any]] = [[String:Any]]()
		for id in ids
		{
			var dataJSON : [String:Any] = [String:Any]()
			dataJSON[ResponseJSONKeys.id] = String(id)
			dataJSON[fieldAPIName] = value
			dataArray.append(dataJSON)
		}
		reqBodyObj[getJSONRootKey()] = dataArray

		setUrlPath(urlPath : "/\(self.module.getAPIName())")
		setRequestMethod(requestMethod : .PUT )
		setRequestBody(requestBody : reqBodyObj )
		let request : APIRequest = APIRequest(handler: self )
		
        print( "Request : \( request.toString() )" )
		
        request.getBulkAPIResponse { ( response, err ) in
            if let error = err
            {
                completion( nil, nil, error )
                return
            }
            if let bulkResponse = response
            {
                let responses : [EntityResponse] = bulkResponse.getEntityResponses()
                var updatedRecords : [ZCRMRecord] = [ZCRMRecord]()
                for entityResponse in responses
                {
                    if(CODE_SUCCESS == entityResponse.getStatus())
                    {
                        let entResponseJSON : [String:Any] = entityResponse.getResponseJSON()
                        let recordJSON : [String:Any] = entResponseJSON.getDictionary(key: DETAILS)
                        let record : ZCRMRecord = ZCRMRecord(moduleAPIName: self.module.getAPIName(), recordId: recordJSON.getInt64( key : ResponseJSONKeys.id ) )
                        EntityAPIHandler(record: record).setRecordProperties(recordDetails: recordJSON)
                        updatedRecords.append(record)
                        entityResponse.setData(data: record)
                    }
                    else
                    {
                        entityResponse.setData(data: nil)
                    }
                }
                bulkResponse.setData( data : updatedRecords )
                completion( updatedRecords, bulkResponse, nil )
            }
        }
	}
    
    internal func upsertRecords( records : [ ZCRMRecord ], completion : @escaping( [ ZCRMRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        setJSONRootKey( key : JSONRootKey.DATA )
        if ( records.count > 100 )
        {
            completion( nil, nil, ZCRMError.MaxRecordCountExceeded( code : MAX_COUNT_EXCEEDED, message : "Cannot process more than 100 records at a time." ) )
        }
        var reqBodyObj : [ String : [ [ String : Any ] ] ] = [ String : [ [ String : Any ] ] ]()
        var dataArray : [ [ String : Any ] ] = [ [ String : Any ] ]()
        for record in records
        {
            let recordJSON = EntityAPIHandler(record : record ).getZCRMRecordAsJSON() as Any as! [String : Any]
            dataArray.append( recordJSON as Any as! [String : Any] )
        }
        reqBodyObj[getJSONRootKey()] = dataArray
		
		setUrlPath(urlPath:  "/\( self.module.getAPIName() )/upsert")
		setRequestMethod(requestMethod: .POST )
		setRequestBody(requestBody: reqBodyObj )
		let request : APIRequest = APIRequest(handler: self )
        print( "Request : \( request.toString() )" )
		
        request.getBulkAPIResponse { ( response, err ) in
            if let error = err
            {
                completion( nil, nil, error )
                return
            }
            if let bulkResponse = response
            {
                let responses : [ EntityResponse ] = bulkResponse.getEntityResponses()
                var upsertRecords : [ ZCRMRecord ] = [ ZCRMRecord ]()
                for entityResponse in responses
                {
                    if(CODE_SUCCESS == entityResponse.getStatus())
                    {
                        let entResponseJSON : [ String : Any ] = entityResponse.getResponseJSON()
                        let recordJSON : [ String : Any ] = entResponseJSON.getDictionary( key : DETAILS)
                        let record : ZCRMRecord = ZCRMRecord( moduleAPIName : self.module.getAPIName(), recordId : recordJSON.getInt64( key : ResponseJSONKeys.id ) )
                        EntityAPIHandler( record : record ).setRecordProperties( recordDetails : recordJSON )
                        upsertRecords.append( record )
                        entityResponse.setData( data : record )
                    }
                    else
                    {
                        entityResponse.setData( data : nil )
                    }
                }
                bulkResponse.setData( data : upsertRecords )
                completion( upsertRecords, bulkResponse, nil )
            }
        }
    }
    
    internal func deleteRecords( ids : [ Int64 ], completion : @escaping( BulkAPIResponse?, Error? ) -> () )
    {
        if(ids.count > 100)
        {
            completion( nil, ZCRMError.MaxRecordCountExceeded( code : MAX_COUNT_EXCEEDED, message : "Cannot process more than 100 records at a time.") )
        }
        var idsStr : String = "\(ids)"
        idsStr = idsStr.replacingOccurrences(of: " ", with: "")
        idsStr = idsStr.replacingOccurrences(of: "[", with: "")
        idsStr = idsStr.replacingOccurrences(of: "]", with: "")
		setUrlPath(urlPath : "/\(self.module.getAPIName())")
		setRequestMethod(requestMethod: .DELETE )
		addRequestParam(param:  "ids" , value: idsStr )
		let request : APIRequest = APIRequest(handler: self )
        print( "Request : \( request.toString() )" )
        
        request.getBulkAPIResponse { ( response, err ) in
            if let error = err
            {
                completion( nil, error )
                return
            }
            if let bulkResponse = response
            {
                let responses : [EntityResponse] = bulkResponse.getEntityResponses()
                for entityResponse in responses
                {
                    let entResponseJSON : [String:Any] = entityResponse.getResponseJSON()
                    let recordJSON : [String:Any] = entResponseJSON.getDictionary(key: DETAILS)
                    let record : ZCRMRecord = ZCRMRecord(moduleAPIName: self.module.getAPIName(), recordId: recordJSON.getInt64( key : ResponseJSONKeys.id ) )
                    entityResponse.setData(data: record)
                }
                completion( bulkResponse, nil )
            }
        }
    }
    
    internal func getDeletedRecords( modifiedSince : String?, page : Int, perPage : Int, completion : @escaping( [ ZCRMTrashRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        self.getDeletedRecords( type : RequestParamValues.all, modifiedSince : modifiedSince, page : page, perPage : perPage ) { ( deletedRecords, response, error ) in
            completion( deletedRecords, response, error )
        }
    }
    
    internal func getRecycleBinRecords( completion : @escaping( [ ZCRMTrashRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        self.getDeletedRecords(type: RequestParamValues.recycle, modifiedSince: nil, page: 1, perPage: 100) { ( deletedRecords, response, error ) in
            completion( deletedRecords, response, error )
        }
    }
    
    internal func getPermanentlyDeletedRecords( completion : @escaping( [ ZCRMTrashRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
        self.getDeletedRecords(type: RequestParamValues.permanent, modifiedSince: nil, page: 1, perPage: 100) { ( deletedRecords, response, error ) in
            completion( deletedRecords, response, error )
        }
    }
    
    private func getDeletedRecords( type : String, modifiedSince : String?, page : Int, perPage : Int, completion : @escaping( [ ZCRMTrashRecord ]?, BulkAPIResponse?, Error? ) -> () )
    {
		setUrlPath(urlPath : "/\( self.module.getAPIName() )/deleted")
		setRequestMethod(requestMethod : .GET )
		addRequestParam(param: RequestParamKeys.type , value: type )
        if ( modifiedSince.notNilandEmpty)
        {
            addRequestHeader(header: "If-Modified-Since" , value: modifiedSince! )
        }
        addRequestParam( param : "page", value : String( page ) )
        addRequestParam( param : "per_page", value : String( perPage ) )
		let request : APIRequest = APIRequest(handler: self )
        print( "Request : \( request.toString() )" )
        request.getBulkAPIResponse { ( response, err ) in
            if let error = err
            {
                completion( nil, nil, error )
                return
            }
            if let bulkResponse = response
            {
                let responses : [ EntityResponse ] = bulkResponse.getEntityResponses()
                var trashRecords : [ ZCRMTrashRecord ] = [ ZCRMTrashRecord ]()
                for entityResponse in responses
                {
                    let trashRecordDetails : [ String : Any ] = entityResponse.getResponseJSON()
                    self.trashRecord = ZCRMTrashRecord(type : trashRecordDetails.getString( key : RequestParamKeys.type ), entityId : trashRecordDetails.getInt64( key : ResponseJSONKeys.id) )
                    self.setTrashRecordProperties( record : trashRecordDetails )
                    trashRecords.append( self.trashRecord )
                }
                bulkResponse.setData( data : trashRecords )
                completion( trashRecords, bulkResponse, nil )
            }
        }
    }
	
	// MARK: - Utility Functions
	
    private func setTrashRecordProperties( record : [ String : Any ] )
    {
        for ( fieldAPIName, value ) in record
        {
            if( ResponseJSONKeys.createdBy == fieldAPIName )
            {
                let createdBy : [ String : Any ] = value as! [ String : Any ]
                let createdByUser : ZCRMUser = ZCRMUser( userId : createdBy.getInt64( key : ResponseJSONKeys.id ), userFullName : createdBy.getString( key : ResponseJSONKeys.name) )
                self.trashRecord.setCreatedBy( createdBy : createdByUser )
            }
            else if( ResponseJSONKeys.deletedBy == fieldAPIName )
            {
                let deletedBy : [ String : Any ] = value as! [ String : Any ]
                let deletedByUser : ZCRMUser = ZCRMUser( userId : deletedBy.getInt64( key : ResponseJSONKeys.id ), userFullName : deletedBy.getString( key : ResponseJSONKeys.name ) )
                self.trashRecord.setDeletedBy( deletedBy : deletedByUser )
            }
            else if( ResponseJSONKeys.displayName == fieldAPIName )
            {
                self.trashRecord.setDisplayName( name : record.getString( key : fieldAPIName ) )
            }
            else if( ResponseJSONKeys.deletedTime == fieldAPIName )
            {
                self.trashRecord.setDisplayName( name : record.getString( key : fieldAPIName ) )
            }
        }
    }
    
    internal func addTags( recordIds : [Int64], tags : [ZCRMTag], overWrite : Bool?, completion : @escaping( [ZCRMRecord]?, BulkAPIResponse?, Error? ) -> () )
    {

        setJSONRootKey(key: JSONRootKey.DATA)
        var addedRecords : [ZCRMRecord] = [ZCRMRecord]()
        var idString : String = String()
        for index in 0..<recordIds.count
        {
            idString.append(String(recordIds[index]))
            if ( index != ( recordIds.count - 1 ) )
            {
                idString.append(",")
            }
        }
        var tagNamesString : String = String()
        for index in 0..<tags.count
        {
            if let name = tags[index].getName()
            {
                tagNamesString.append( name )
                if ( index != ( tags.count - 1 ) )
                {
                    tagNamesString.append(",")
                }
            }
        }
        
        setUrlPath(urlPath: "/\(module.getAPIName())/actions/add_tags")
        setRequestMethod(requestMethod: .POST)
        addRequestParam(param: RequestParamKeys.ids, value: idString)
        addRequestParam(param: RequestParamKeys.tagNames, value: tagNamesString)
        if overWrite != nil
        {
            addRequestParam(param: RequestParamKeys.overWrite, value: String(overWrite!))
        }
        
        let request : APIRequest = APIRequest(handler: self)
        print( "Request : \(request.toString())" )
        
        request.getBulkAPIResponse { ( response, err ) in
            if let error = err
            {
                completion( nil, nil, error )
                return
            }
            if let bulkResponse = response
            {
                let responses : [EntityResponse] = bulkResponse.getEntityResponses()
                for entityResponse in responses
                {
                    if(CODE_SUCCESS == entityResponse.getStatus())
                    {
                        let entResponseJSON : [String:Any] = entityResponse.getResponseJSON()

                        let recordDetails : [String : Any] = entResponseJSON.getDictionary(key: DETAILS)
                        let record : ZCRMRecord = ZCRMRecord(moduleAPIName: self.module.getAPIName(), recordId: recordDetails.getInt64(key: ResponseJSONKeys.id))
                        let tagNames : [String] = recordDetails.getArray(key: ResponseJSONKeys.tags) as! [String]
                        for name in tagNames
                        {
                            let tag : ZCRMTag = ZCRMTag(tagName: name)
                            record.addTag(tag: tag)
                        }
                        entityResponse.setData(data: record)
                        addedRecords.append(record)

                    }
                    else
                    {
                        entityResponse.setData(data: nil)
                    }
                }
                bulkResponse.setData(data: addedRecords)
                completion( addedRecords, bulkResponse, nil )
            }
        }
    }
    
    internal func removeTags( recordIds : [Int64], tags : [ZCRMTag], completion : @escaping( BulkAPIResponse?, Error? ) -> () )
    {
        setJSONRootKey(key: JSONRootKey.DATA)
        var idString : String = String()
        for index in 0..<recordIds.count
        {
            idString.append(String(recordIds[index]))
            if ( index != ( recordIds.count - 1 ) )
            {
                idString.append(",")
            }
        }
        var tagNamesString : String = String()
        for index in 0..<tags.count
        {
            if let name = tags[index].getName()
            {
                tagNamesString.append( name )
                if ( index != ( tags.count - 1 ) )
                {
                    tagNamesString.append(",")
                }
            }
        }
        
        setUrlPath(urlPath: "/\(module.getAPIName())/actions/remove_tags")
        setRequestMethod(requestMethod: .POST)
        addRequestParam(param: RequestParamKeys.ids, value: idString)
        addRequestParam(param: RequestParamKeys.tagNames, value: tagNamesString)
        
        let request : APIRequest = APIRequest(handler: self)
        print( "Request : \(request.toString())" )
        
        request.getBulkAPIResponse { ( response, err ) in
            completion( response, err )
        }
    }
}

fileprivate extension MassEntityAPIHandler
{
    struct RequestParamKeys
    {
        static let fields = "fields"
        static let kanbanView = "kanban_view"
        static let ids = "ids"
        static let type = "type"
        static let tagNames = "tag_names"
        static let overWrite =  "over_write"
    }
    
    
    struct RequestParamValues
    {
        static let word = "word"
        static let criteria = "criteria"
        static let email = "email"
        static let phone = "phone"
        static let all = "all"
        static let recycle = "recycle"
        static let permanent = "permanent"
    }

    
    struct ResponseJSONKeys
    {
        static let id = "id"
        static let name = "name"
        static let createdBy = "created_By"
        static let deletedBy = "deleted_by"
        static let displayName = "display_name"
        static let deletedTime = "deleted_time"
        static let tags = "tags"
    }
}
