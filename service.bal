// MIT License

// Copyright (c) 2022 Knnect

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// For more Choreo samples : https://github.dev/wso2-enterprise/choreo-samples/

import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerinax/aws.s3; // https://github.com/ballerina-platform/module-ballerinax-aws.s3
import ballerina/uuid;
// import ballerina/jwt;

configurable string accessKeyId = ""; // AKIAROLRJEOJYXSWMD4O1
configurable string secretAccessKey = ""; // yIn4eexjit7yDS/nng3eqlbVlzM3tW0nprOLJh611
configurable string region = "us-east-1"; // us-east-1
configurable string bucketName = "choreo-todo-sample"; // choreo-todo-sample

s3:ConnectionConfig amazonS3Config = {
    accessKeyId: accessKeyId,
    secretAccessKey: secretAccessKey,
    region: region
};

// Data structure of a Todo record
type TodoRecord record {|
    string text;
    boolean done;
    string id;
|};

// Data structure of a Todo POST (Create) request payload
// Note: Todo ID is not included since ID is generated on the fly when creating the TODO record
type TodoRecordPayload record {|
    string text;
    boolean done;
|};

// Data structure of the list of Todos record
type ToDoList record {
    TodoRecord[] list;
    int length?;
};

s3:Client amazonS3Client = check new (amazonS3Config);

function getTodos(string user) returns ToDoList|error {
    stream<byte[], io:Error?>|error getObjectResponse = amazonS3Client->getObject(bucketName, user + ".json");
    if (getObjectResponse is stream<byte[], io:Error?>) {
        byte[] allBytes = [];
        check from byte[] chunks in getObjectResponse
            do {
                allBytes.push(...chunks);
            };
        io:ReadableCharacterChannel readableCharacterChannel = new (check io:createReadableChannel(allBytes), "UTF-8");
        json todos = check readableCharacterChannel.readJson();
        ToDoList todosList = check todos.fromJsonWithType(ToDoList);
        todosList.length = todosList.list.length();
        return todosList;
    } else {
        return getObjectResponse;
    }
}

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # A resource for retriving the list of todos
    # For Developer testing:  curl -v  http://localhost:9090/todos
    # + return - List of TODO records
    resource function get todos(@http:Header {name: "x-jwt-assertion"} string? headerValue) returns http:Response|error? {
        // @http:Header {name: "x-authorization"} string? headerValue
        // string filteredHeader = <string>headerValue;
        // string[] names = check request.getHeaderNames();
        log:printInfo("###########");
        if headerValue != () {
            log:printInfo(headerValue);
        }

        // foreach string i in names {
        //     log:printInfo(i);
            
        // }
        // string a = check request.getHeader("x-jwt-assertion");
        // log:printInfo(a);

        // [jwt:Header, jwt:Payload] [header, payload] = check jwt:decode(a);
        // log:printInfo(payload.toString());

        string user = "anonymous";
        // TODO: When reading JWT , We don't log user sensitive info
        // decode JWT
        // do signture validation
        // claim validation not required due to internal call
        // x-jwt-assertion
        http:Response response = new;
        ToDoList todos = check getTodos(user);
        response.statusCode = http:STATUS_OK;
        response.setPayload(todos.toJson());
        return response;
    }

    # A resource for creating a new TODO item
    # For Developer testing:  curl -v -X POST -H 'Content-Type: application/json' -d '{"text":"Buy eggs", "done": false}'  http://localhost:9090/todos
    # + return - Newly created TODO record
    resource function post todos(@http:Payload TodoRecordPayload jsonMsg) returns http:Response|error {
        // Send a response back to the caller.
        string user = "anonymous";
        ToDoList|error todos = getTodos(user);
        http:Response response = new;

        string todoID = uuid:createType1AsString();
        TodoRecord newTodo = {...jsonMsg, id: todoID};
        if (todos is error) {
            ToDoList newTodoList = {
                list: [newTodo]
            };
            error? createObjectResponse = amazonS3Client->createObject(bucketName, user + ".json", newTodoList.toJsonString());
            if (createObjectResponse is error) {
                string errorMessage = "Error: while creatig new todo " + createObjectResponse.toString();
                log:printError(errorMessage);
                response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
                response.setPayload({success: false, errorMessage});
            } else {
                response.statusCode = http:STATUS_CREATED;
                response.setPayload(newTodo.toJson());
            }
        } else {
            todos.list.push(newTodo);
            error? createObjectResponse = amazonS3Client->createObject(bucketName, user + ".json", todos.toJsonString());
            if (createObjectResponse is error) {
                string errorMessage = "Error: while creatig new todo " + createObjectResponse.toString();
                log:printError(errorMessage);
                response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
                response.setPayload({success: false, errorMessage});
            } else {
                response.statusCode = http:STATUS_CREATED;
                response.setPayload(newTodo.toJson());
            }
        }
        return response;
    }

    # A resource for updating an exsisting TODO item
    # For Developer testing:  curl -v -X PUT -H 'Content-Type: application/json' -d '{"text":"my_login", "done": true, "id":"01ed3dfd-a275-1c20-b61a-82c8be2ddbf9"}'  http://localhost:9090/todos/01ed3dfd-a275-1c20-b61a-82c8be2ddbf9/
    # + return - Updated TODO record
    resource function put todos/[string todoID](@http:Payload TodoRecord putPayload) returns json|error|http:Response {
        if (todoID != putPayload.id) {
            return error("ID mismatch in path (" + todoID + ") and ID in payload (" + putPayload.id + ") !");
        }
        string user = "anonymous";
        http:Response response = new;
        ToDoList todos = check getTodos(user);
        ToDoList updatedList = todos.clone();
        updatedList.list = [];
        boolean todoIdFound = false;
        foreach TodoRecord todo in todos.list {
            if (todo.id.equalsIgnoreCaseAscii(todoID))
                {
                updatedList.list.push(putPayload);
                todoIdFound = true;
            } else {
                updatedList.list.push(todo);
            }
        }
        if (!todoIdFound) {
            response.statusCode = http:STATUS_NOT_FOUND;
            response.setPayload({success: false, errorMessage: "Can't find " + todoID + " in the records!"});
        } else {
            error? createObjectResponse = amazonS3Client->createObject(bucketName, user + ".json", updatedList.toJsonString());
            if (createObjectResponse is error) {
                string errorMessage = "Error: while updating the TODO <" + todoID + "> " + createObjectResponse.toString();
                log:printError(errorMessage);
                response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
                response.setPayload({success: false, errorMessage});

            } else {
                log:printInfo("TODO < " + todoID + " > updated successfully");
                response.statusCode = http:STATUS_OK;
                response.setPayload(putPayload);
            }
        }
        return response;
    }

    # A resource for deleting an exsisting TODO item
    # For Developer testing:  curl -v -X DELETE  http://localhost:9090/todos/01ed3dfd-a275-1c20-b61a-82c8be2ddbf9
    # + return - Delete operation status
    resource function delete todos/[string todoID]() returns error|http:Response {
        string user = "anonymous";
        http:Response response = new;
        boolean todoIdFound = false;
        ToDoList todos = check getTodos(user);
        ToDoList updatedList = todos.clone();

        updatedList.list = todos.list.filter(function(TodoRecord todo) returns boolean {
            if (todo.id == todoID) {
                todoIdFound = true;
                return false;
            } else {
                return true;
            }
        });
        if (!todoIdFound) {
            response.statusCode = http:STATUS_NOT_FOUND;
            response.setPayload({success: false, errorMessage: "Can't find " + todoID + " in the records!"});
        } else {
            error? createObjectResponse = amazonS3Client->createObject(bucketName, user + ".json", updatedList.toJsonString());
            if (createObjectResponse is error) {
                string errorMessage = "Error: while updating the TODO <" + todoID + "> " + createObjectResponse.toString();
                log:printError(errorMessage);
                response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
                response.setPayload({success: false, errorMessage});

            } else {
                log:printInfo("TODO updated successfully");
                response.statusCode = http:STATUS_OK;
                response.setPayload({success: true});
            }
        }
        return response;
    }
}
