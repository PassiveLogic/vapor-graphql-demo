import Vapor
import GraphQL
import Graphiti
import Pioneer

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.middleware.use(
        server.vaporMiddleware(context: { req, res in
            return Context(eventLoop: req.eventLoop)
        }, websocketContext: { req, res, gql in
            return Context(eventLoop: req.eventLoop)
        })
    )
    // register routes
    try routes(app)
}

/// Delivered to each resolver
struct Context {
    let eventLoop: EventLoop
}

struct Resolver {
    func hello(ctx: Context, args: HelloArguments) -> String {
        return "\(args.name)!"
    }
    
    func currentUser(ctx: Context, args: NoArguments) -> User {
        print("in currentUser")
        return User(firstName: "Jay", lastName: "Herron")
    }
    
    func incrementingTimer(ctx: Context, args: NoArguments) -> EventStream<Int> {
        var count = 0
        let asyncStream = AsyncThrowingStream<Int, Error> { continuation in
            ctx.eventLoop.scheduleRepeatedTask(initialDelay: .zero, delay: .seconds(1)) { task in
                count = count + 1
                continuation.yield(count)
            }
            continuation.yield(count)
        }
        return asyncStream.toEventStream()
    }
}

let schema = try! Schema<Resolver, Context> {
    Type(User.self) {
        Field("firstName", at: \.firstName)
        Field("lastName", at: \.lastName)
        Field("organization", at: User.organization)
    }
    
    Type(Organization.self) {
        Field("name", at: \.name)
    }
    
    Query {
        Field("currentUser", at: Resolver.currentUser)
        Field("hello", at: Resolver.hello) {
            Argument("name", at: \.name)
        }
    }
    
    Subscription {
        SubscriptionField("incrementingCounter", as: Int.self, atSub: Resolver.incrementingTimer)
    }
}

let server = Pioneer(
    schema: schema,
    resolver: .init(),
    introspection: true,
    playground: .graphiql
)

struct HelloArguments: Codable {
    let name: String
}

struct User {
    let firstName: String
    let lastName: String
//    let organization: Organization
    
    func organization(ctx: Context, args: NoArguments) -> Organization {
        print("in organization")
        return .init(name: "PassiveLogic!")
    }
}

struct Organization {
    let name: String
}
