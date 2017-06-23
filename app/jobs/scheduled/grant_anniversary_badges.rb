module Jobs
  class GrantAnniversaryBadges < Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges?

      start_date = args[:start_date] || 1.year.ago
      end_date = start_date + 1.year

      fmt_end_date = end_date.iso8601(6)
      fmt_start_date = start_date.iso8601(6)

      results = User.exec_sql <<~SQL
        SELECT u.id AS user_id
        FROM users AS u
        INNER JOIN posts AS p ON p.user_id = u.id
        INNER JOIN topics AS t ON p.topic_id = t.id
        LEFT OUTER JOIN user_badges AS ub ON ub.user_id = u.id AND
          ub.badge_id = #{Badge::Anniversary} AND
          ub.granted_at BETWEEN '#{fmt_start_date}' AND '#{fmt_end_date}'
        WHERE u.active AND
          NOT u.blocked AND
          NOT p.hidden AND
          p.deleted_at IS NULL AND
          t.visible AND
          t.archetype <> 'private_message' AND
          p.created_at BETWEEN '#{fmt_start_date}' AND '#{fmt_end_date}' AND
          u.created_at <= '#{fmt_start_date}'
        GROUP BY u.id
        HAVING COUNT(p.id) > 0 AND COUNT(ub.id) = 0
      SQL

      badge = Badge.find(Badge::Anniversary)
      user_ids = results.map { |r| r['user_id'].to_i }

      User.where(id: user_ids).find_each do |user|
        BadgeGranter.grant(badge, user, created_at: end_date)
      end
    end

  end
end
