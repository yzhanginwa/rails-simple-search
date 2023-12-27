require 'minitest/autorun'
require 'rails-simple-search'
require_relative 'support'

class RailsSimpleSearchTest < Minitest::Test
  def test_direct_attributes
    search = Search.new(:user, { 'first_name': 'Mike' }, exact_match: [:first_name])
    users = search.run
    assert_equal users.joins, ''
    assert_equal users.conditions, ['(users.first_name = ?)', 'Mike']
    assert_equal users.selects, 'distinct users.*'
  end

  def test_association_attributes
    search = Search.new(:user, { 'posts.title': 'my first post' }, exact_match: [:first_name])
    users = search.run
    assert_equal users.joins, ' inner join posts AS A01 on users.id = A01.user_id'
    assert_equal users.conditions, ['(A01.title like ?)', '%my first post%']
    assert_equal users.selects, 'distinct users.*'
  end

  def test_polymorphic_association_attributes
    search = Search.new(:user, { 'address.city': 'seattle' }, exact_match: [:first_name])
    users = search.run
    assert_equal users.joins, " inner join addresses AS A01 on A01.addressable_type = 'User' and users.id = A01.addressable_id"
    assert_equal users.conditions, ['(A01.city like ?)', '%seattle%']
    assert_equal users.selects, 'distinct users.*'
  end

  def test_association_loop_attributes
    search = Search.new(:user, { 'posts.comments.user.first_name': 'Nancy' }, exact_match: [:first_name])
    users = search.run
    assert_equal users.joins, ' inner join posts AS A01 on users.id = A01.user_id inner join comments AS A02 on A01.id = A02.post_id inner join users AS A03 on A02.user_id = A03.id'
    assert_equal users.conditions, ['(A03.first_name = ?)', 'Nancy']
    assert_equal users.selects, 'distinct users.*'
  end

  def test_association_loop_with_or_attributes
    search = Search.new(:user, { 'posts.comments.user.first_name_or_posts.comments.user.last_name': 'Nancy' }, exact_match: [:first_name])
    users = search.run
    assert_equal users.joins, ' inner join posts AS A01 on users.id = A01.user_id inner join comments AS A02 on A01.id = A02.post_id inner join users AS A03 on A02.user_id = A03.id'
    assert_equal users.conditions, ['((A03.first_name = ? or A03.last_name like ?))', 'Nancy', '%Nancy%']
    assert_equal users.selects, 'distinct users.*'
  end
end
