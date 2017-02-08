# frozen_string_literal: true
require 'rails_helper'

RSpec.feature 'Special group editing' do
  before { log_in FactoryGirl.create(:admin) }

  it 'succeeds when changing size' do
    group = FactoryGirl.create(:drawless_group)
    new_suite = FactoryGirl.create(:suite_with_rooms, rooms_count: 5)
    visit edit_group_path(group)
    update_group_size(new_suite.size)
    expect(page).to have_css('.group-size', text: new_suite.size)
  end

  # rubocop:disable RSpec/ExampleLength
  it 'succeeds when switching in a user from a draw' do
    group = FactoryGirl.create(:drawless_group, size: 2)
    remove = FactoryGirl.create(:student, intent: 'on_campus')
    group.members << remove
    add = FactoryGirl.create(:student_in_draw, intent: 'off_campus')
    visit edit_group_path(group)
    select remove.full_name, from: 'group_remove_ids'
    select add.full_name_with_intent, from: 'group_member_ids'
    click_on 'Save'
    expect(page).to have_css('.group-member', text: add.full_name)
  end

  it 'fails even when memberships are invalid' do
    group = FactoryGirl.create(:drawless_group, size: 1)
    add = FactoryGirl.create(:student_in_draw)
    visit edit_group_path(group)
    select add.full_name_with_intent, from: 'group_member_ids'
    click_on 'Save'
    expect(page).to have_css('.flash-error')
  end
  # rubocop:enable RSpec/ExampleLength

  def update_group_size(new_size)
    select new_size, from: 'group_size'
    click_on 'Save'
  end
end
