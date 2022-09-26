import ballerina/http;
import ballerina/io;
import ballerina/log;
// import ballerina/lang.'string as strings;
import ballerinax/aws.s3;

configurable string accessKeyId = ?; // AKIAROLRJEOJYXSWMD4O1
configurable string secretAccessKey = ?; // yIn4eexjit7yDS/nng3eqlbVlzM3tW0nprOLJh611
configurable string region = ?; // us-east-1
configurable string bucketName = ?;

s3:ConnectionConfig amazonS3Config = {
    accessKeyId: accessKeyId,
    secretAccessKey: secretAccessKey,
    region: region
};

type TodoRecord record {|
    string text;
|};

s3:Client amazonS3Client = check new (amazonS3Config);

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # A resource for generating greetings
    # + name - the input string name
    # + return - string name with hello message or error
    resource function get todos(http:Caller caller, http:Request request) returns error? {
        stream<byte[], io:Error?>|error getObjectResponse = amazonS3Client->getObject(bucketName, "user.json");
        http:Response response = new;
        if (getObjectResponse is stream<byte[], io:Error?>) {
            byte[] allBytes = [];
            check from byte[] chunks in getObjectResponse
                do {
                    allBytes.push(...chunks);
                };
            io:ReadableCharacterChannel readableCharacterChannel = new (check io:createReadableChannel(allBytes), "UTF-8");
            json todos = check readableCharacterChannel.readJson();
            response.statusCode = http:STATUS_OK;
            response.setPayload(todos);

        } else {
            log:printError("Error: " + getObjectResponse.toString());
            response.statusCode = http:STATUS_BAD_REQUEST;
            response.setPayload(getObjectResponse.toString());
        }
        check caller->respond(response);

    }

    // curl -X POST -H 'Content-Type: application/json' -d '{"text":"my_login"}'  http://localhost:9090/todos
    resource function post todos(@http:Payload TodoRecord jsonMsg) returns json|error {
        // Send a response back to the caller.
        error? createObjectResponse = amazonS3Client->createObject(bucketName, "user.json", jsonMsg.toJsonString());
        if (createObjectResponse is error) {
            log:printError("Error: " + createObjectResponse.toString());
        } else {
            log:printInfo("Object created successfully");
        }
        return {success: true};
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
