require_relative 'repo_auditor'
require_relative '../models/configurations'
require_relative '../models/projects'

class RepoEnqueuer
    include Sidekiq::Worker
    sidekiq_options :queue => :enqueue_repos

    def perform
        projects = Projects.where { next_audit <= Time.now.to_i }
        config = Configurations.first unless projects.empty?
        projects.each do |p|
            rule_ids = JSON.parse(config[:global_rules])
            if p[:rules]
                if config[:ignore_global_rules]
                    rule_ids = JSON.parse(p[:rules])
                else
                    puts JSON.parse(p[:rules])
                    rule_ids += JSON.parse(p[:rules])
                end
            end
            rules = Rules.graph(:rule_types, :id => :rule_type_id)
                .where(:rules__id => rule_ids)
                .select(:rules__id, :rules__rule, :rule_types__name)

            last_commit_time = p[:last_commit_time] || Time.at(0)
            RepoAuditor.perform_async(p[:id], p[:name], last_commit_time,
                config[:github_token], config[:audit_frequency], rules.to_json)
        end
    end
end
