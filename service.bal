import ballerina/http;

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # A resource for generating greetings
    # + name - the input string name
    # + return - string name with hello message or error
    resource function get todos(string name) returns string|error {
        // Send a response back to the caller.
        if name is "" {
            return error("name should not be empty!");
        }
        return "Hello, " + name;
    }

    resource function post todos(string name) returns string|error {
        // Send a response back to the caller.
        if name is "" {
            return error("name should not be empty!");
        }
        return "Hello, " + name;
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
