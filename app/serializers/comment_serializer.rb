class CommentSerializer
    def self.serialize(comment)
      {
        id: comment.id,
        name: comment.name,
        email: comment.email,
        body: comment.body,
        translated_body: comment.translated_body,
        status: comment.status,
        keyword_count: comment.keyword_count,
        post_id: comment.post_id
      }
    end
  end