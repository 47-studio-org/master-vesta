# frozen_string_literal: true

FactoryBot.define do
  factory :user, aliases: %i(student) do
    sequence(:email) { |n| "email#{n}@email.com" }
    password { 'passw0rd' }
    sequence(:first_name) { |n| "First_#{n}" }
    last_name { 'Last' }
    role { 'student' }
    intent { 'on_campus' }
    class_year { Time.zone.today.year }
    username { first_name.downcase if env? 'CAS_BASE_URL' }
    tos_accepted { Time.zone.now }
    college_id { College.current.id }

    factory :student_in_draw do
      after(:build) do |user|
        user.draw = build(:draw)
      end
      after(:create) do |user|
        user.update_attributes(draw: create(:draw_with_members))
      end
    end

    factory :admin do
      role { 'admin' }
      tos_accepted { nil }
    end
  end
end
