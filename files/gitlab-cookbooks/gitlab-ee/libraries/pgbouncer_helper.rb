class PgbouncerHelper
  attr_reader :node

  def initialize(node)
    @node = node
  end

  def database_config(database)
    settings = node['gitlab']['pgbouncer']['databases'][database].to_hash
    # The recipe uses user and passowrd for the auth_user option and the pg_auth file
    settings['auth_user'] = settings.delete('user') if settings.key?('user')
    settings.delete('password') if settings.key?('password')
    settings.map do |setting, value|
      "#{setting}=#{value}"
    end.join(' ').chomp
  end
end
