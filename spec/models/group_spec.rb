# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Group, type: :model do
  describe 'basic validations' do
    subject { FactoryGirl.build(:group) }
    it { is_expected.to validate_presence_of(:size) }
    it { is_expected.to allow_value(1).for(:size) }
    it { is_expected.not_to allow_value(0).for(:size) }
    it { is_expected.not_to allow_value(-1).for(:size) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to belong_to(:leader) }
    it { is_expected.to validate_presence_of(:leader) }
    it { is_expected.to belong_to(:draw) }
    it { is_expected.to have_one(:suite) }
    it { is_expected.to have_many(:memberships) }
    it { is_expected.to have_many(:full_memberships) }
    it { is_expected.to have_many(:members).through(:full_memberships) }
    it { is_expected.not_to allow_value(-1).for(:memberships_count) }
    it { is_expected.to validate_presence_of(:transfers) }
    it { is_expected.not_to allow_value(-1).for(:transfers) }
  end

  describe 'size validations' do
    context 'for regular groups' do
      it 'must be available in the draw' do
        group = FactoryGirl.build(:group)
        allow(group.draw).to receive(:open_suite_sizes).and_return([1])
        group.size = 2
        expect(group.valid?).to be_falsey
      end
    end
    context 'for drawless groups' do
      it 'must be an existing suite size' do
        group = FactoryGirl.build(:drawless_group)
        allow(SuiteSizesQuery).to receive(:call).and_return([1])
        group.size = 2
        expect(group).not_to be_valid
      end
    end
    it 'must not have more members than the size' do
      group = FactoryGirl.create(:full_group, size: 2)
      allow(group.draw).to receive(:suite_sizes).and_return([1, 2])
      group.size = 1
      expect(group.valid?).to be_falsey
    end
    it 'also validates during creation' do
      leader, student = FactoryGirl.create_pair(:student)
      group = described_class.new(size: 1, leader_id: leader.id,
                                  member_ids: [student.id])
      group.save
      expect(group.persisted?).to be_falsey
    end
    it 'takes transfers into account' do
      group = FactoryGirl.create(:open_group, size: 2, transfers: 1)
      expect(group).to be_full
    end
  end

  describe 'status validations' do
    it 'can only be locked if the number of members match the size' do
      group = FactoryGirl.build(:open_group)
      group.status = 'locked'
      expect(group.valid?).to be_falsey
    end
    it 'can only be locked if all memberships are locked' do
      # finalizing locks the leader only, not any of the members
      group = FactoryGirl.create(:finalizing_group, size: 2)
      group.status = 'locked'
      expect(group.valid?).to be_falsey
    end
    it 'cannot be full when there are less members than the size' do
      group = FactoryGirl.build(:open_group)
      group.status = 'full'
      expect(group.valid?).to be_falsey
    end
    it 'takes transfers into account' do
      group = FactoryGirl.create(:open_group, size: 2, transfers: 1)
      group.status = 'open'
      expect(group).not_to be_valid
    end
    it 'cannot be open when members match the size' do
      group = FactoryGirl.create(:full_group, size: 2)
      group.status = 'open'
      expect(group.valid?).to be_falsey
    end
  end

  it 'destroys dependent memberships on destruction' do
    group = FactoryGirl.create(:drawless_group)
    membership_ids = group.memberships.map(&:id)
    group.destroy
    expect { Membership.find(membership_ids) }.to \
      raise_error(ActiveRecord::RecordNotFound)
  end

  describe 'leader is included as a member' do
    it do
      group = FactoryGirl.create(:group)
      expect(group.members).to include(group.leader)
    end
  end

  describe '#name' do
    it "includes the leader's name" do
      leader = instance_spy('User', name: 'Name')
      group = FactoryGirl.build_stubbed(:group)
      allow(group).to receive(:leader).and_return(leader)
      expect(group.name).to include(leader.name)
    end
  end

  describe '#requests' do
    it 'returns an array of users who have requested to join' do
      group = FactoryGirl.create(:open_group)
      user = FactoryGirl.create(:student, intent: 'on_campus', draw: group.draw)
      Membership.create(group: group, user: user, status: 'requested')
      expect(group.requests).to eq([user])
    end
  end

  describe '#invitations' do
    it 'returns an array of users who have been invited to join' do
      group = FactoryGirl.create(:open_group)
      user = FactoryGirl.create(:student, intent: 'on_campus', draw: group.draw)
      Membership.create(group: group, user: user, status: 'invited')
      expect(group.invitations).to eq([user])
    end
  end

  describe '#members' do
    it 'returns only members with an accepted membership' do
      group = FactoryGirl.create(:open_group)
      create_potential_member(status: 'invited', group: group)
      create_potential_member(status: 'requested', group: group)
      expect(group.reload.members.map(&:id)).to eq([group.leader.id])
    end

    def create_potential_member(status:, group:)
      u = FactoryGirl.create(:student, draw: group.draw, intent: 'on_campus')
      Membership.create(user: u, group: group, status: status)
      u
    end
  end

  describe '#removable_members' do
    it 'returns all accepted members except for the leader' do
      group = FactoryGirl.create(:full_group, size: 2)
      expect(group.removable_members.map(&:id)).not_to include(group.leader_id)
    end
  end

  describe '#destroy' do
    it 'restores members to their original draws if drawless' do
      group = FactoryGirl.create(:drawless_group)
      allow(group.leader).to receive(:restore_draw)
        .and_return(instance_spy('user', save: true))
      group.destroy
      expect(group.leader).to have_received(:restore_draw)
    end
    it 'does nothing if group belongs to a draw' do
      group = FactoryGirl.create(:group)
      allow(group.leader).to receive(:restore_draw)
      group.destroy
      expect(group.leader).not_to have_received(:restore_draw)
    end
  end

  describe '#locked_members' do
    it 'returns memberships that are locked' do
      group = FactoryGirl.create(:finalizing_group)
      expect(group.locked_members).to eq([group.leader])
    end
  end

  describe '#lockable?' do
    it 'returns true when all members are locked, and group is full' do
      group = FactoryGirl.create(:finalizing_group)
      group.full_memberships.reject(&:locked).each do |m|
        m.update(locked: true)
      end
      expect(group.reload).to be_lockable
    end
  end
end
