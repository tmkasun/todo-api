import ballerina/http;
import ballerina/io;
import ballerina/log;
// import ballerina/lang.'string as strings;
import ballerinax/aws.s3;
import ballerina/uuid;

configurable string accessKeyId = "AKIAROLRJEOJYXSWMD4O"; // AKIAROLRJEOJYXSWMD4O1
configurable string secretAccessKey = "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"; // yIn4eexjit7yDS/nng3eqlbVlzM3tW0nprOLJh611
configurable string region = "us-east-1"; // us-east-1
configurable string bucketName = "choreo-todo-sample"; // choreo-todo-sample

s3:ConnectionConfig amazonS3Config = {
    accessKeyId: accessKeyId,
    secretAccessKey: secretAccessKey,
    region: region
};

type TodoRecord record {|
    string text;
    boolean done;
    string id;
|};

type TodoRecordPayload record {|
    string text;
    boolean done;
|};

type ToDoList record {
    TodoRecord[] list;
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
        return todosList;
    } else {
        return getObjectResponse;
    }
}

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # A resource for generating greetings
    # + name - the input string name
    # + return - string name with hello message or error
    resource function get todos(http:Caller caller, http:Request request) returns error? {
        string user = "anonymous";
        http:Response response = new;
        ToDoList todos = check getTodos(user);
        response.statusCode = http:STATUS_OK;
        response.setPayload(todos.toJson());
        check caller->respond(response);
    }

    // curl -v -X POST -H 'Content-Type: application/json' -d '{"text":"my_login", "done": false}'  http://localhost:9090/todos
    resource function post todos(@http:Payload TodoRecordPayload jsonMsg) returns json|error {
        // Send a response back to the caller.
        string user = "anonymous";
        ToDoList|error todos = getTodos(user);
        string todoID = uuid:createType1AsString();
        TodoRecord newTodo = {...jsonMsg, id: todoID};
        if (todos is error) {
            ToDoList newTodoList = {
                list: [newTodo]
            };
            error? createObjectResponse = amazonS3Client->createObject(bucketName, user + ".json", newTodoList.toJsonString());
            if (createObjectResponse is error) {
                log:printError("Error: " + createObjectResponse.toString());
            } else {
                log:printInfo("Object created successfully");
            }
            return {success: true};
        } else {
            todos.list.push(newTodo);
            error? createObjectResponse = amazonS3Client->createObject(bucketName, user + ".json", todos.toJsonString());
            if (createObjectResponse is error) {
                log:printError("Error: " + createObjectResponse.toString());
            } else {
                log:printInfo("Object created successfully");
            }
            return {success: true};
        }
    }

    resource function put todos/[string todoID]() returns json|error {
        // Send a response back to the caller.
        if todoID is "" {
            return error("name should not be empty!");
        }
        return "Hello, " + todoID;
    }

    resource function delete todos/[string todoID]() returns string|error {
        // Send a response back to the caller.
        if todoID is "" {
            return error("name should not be empty!");
        }
        return "Hello, " + todoID;
    }
}
