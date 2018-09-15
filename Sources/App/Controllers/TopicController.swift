import Vapor
import Leaf

final class TopicController {

    func renderList(req: Request) throws -> Future<View> {
        return Topic.query(on: req).all().flatMap { topics in
            let topicsWithVotes = try topics.map { topic in
                return TopicWithVotes(
                    topic: topic,
                    votes: try topic.userVotes.query(on: req).count()
                )
            }

            let viewData = ViewData(
                isUser: try req.isAuthenticated(User.self),
                topicsWithVotes: topicsWithVotes
            )

            return try req.view().render("Topic/list", viewData)
        }
    }

    func create(req: Request) throws -> Future<Response> {
        guard let user: User = try req.authenticated() else {
            return req.future(req.redirect(to: "/topics"))
        }

        return try req.content.decode(TopicForm.self).flatMap { topicForm -> Future<Topic> in
            let userId = try user.requireID()
            return Topic(description: topicForm.description, userID: userId).save(on: req)
        }.flatMap { topic in
            return topic.userVotes.attach(user, on: req)
        }.transform(to: req.redirect(to: "/topics"))
    }
}

struct TopicWithVotes: Encodable {
    var topic: Topic
    var votes: Future<Int>
}

struct ViewData: Encodable {
    var isUser: Bool
    var topicsWithVotes: [TopicWithVotes]
}
