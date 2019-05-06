require 'rubygems'
require 'aws-sdk-core'
require 'aws-sdk-mturk'


module Turkee
  # adapted heavily from rturk
  class TurkAPI
    attr_accessor :mturk_client
    cattr_accessor :aws_credentials, :opts

    def initialize
      attrs = {
        endpoint: TurkAPI.sandbox? ?  "https://mturk-requester-sandbox.us-east-1.amazonaws.com" : 'https://mturk-requester.us-east-1.amazonaws.com',
        credentials: aws_credentials
      }.merge(opts.slice(:region) || {})
      self.mturk_client = Aws::MTurk::Client.new(attrs)
    end

    def self.setup(access_key_id, secret_access_key, opts)
      self.aws_credentials = Aws::Credentials.new(access_key_id, secret_access_key)
      self.opts = opts
    end

    def self.sandbox?
      if opts && opts.key?(:sandbox)
        opts[:sandbox]
      else
        !Rails.env.production?
      end
    end

    def build_url(host, model, params, opts)
      if opts[:form_url]
        full_url(opts[:form_url], params)
      else
        form_url(host, model, params)
      end
    end

    # Returns the default url of the model's :new route
    def form_url(host, typ, params = {})
      @app ||= ActionDispatch::Integration::Session.new(Rails.application)
      url = (host + @app.send("new_#{typ.to_s.underscore}_path"))
      full_url(url, params)
    end

    # Appends params to the url as a query string
    def full_url(u, params)
      url = u
      url = "#{u}?#{params.to_query}" unless params.empty?
      url
    end
     def comp_map
      {:gt => 'GreaterThan', :lt => 'LessThan', :gte => 'GreaterThanOrEqualTo',
                            :lte => 'LessThanOrEqualTo', :eql => 'EqualTo', :not => 'NotEqualTo', :exists => 'Exists'}
     end

     def qualification_map
      {
         :approval_rate => '000000000000000000L0', :submission_rate => '00000000000000000000',
         :abandoned_rate => '00000000000000000070', :return_rate => '000000000000000000E0',
         :rejection_rate => '000000000000000000S0', :hits_approved => '00000000000000000040',
         :adult => '00000000000000000060', :country => '00000000000000000071',
       }
     end
     # IN: { approval_rate: { gt: 70 }, country: { eql: 'US' } }
     # OUT: [
     #   Aws::MTurk::Types::QualificationRequirement.new({
     #     qualification_type_id: '000000000000000000L0', comparator: "GreaterThan", integer_values: [ 70 ]
     #   }),
     #   Aws::MTurk::Types::QualificationRequirement.new({
     #     qualification_type_id: '00000000000000000071', comparator: "EqualTo", locale_values: [ Aws::MTurk::Types::Locale.new( country: 'US' ]
     #   })
     #
     # ]
     def qualification_as_mturk(type, comp_hash)
      if qualification_map[type]
        Aws::MTurk::Types::QualificationRequirement.new({
          qualification_type_id: qualification_map[type],
          comparator: comp_map[comp_hash.keys.first],
          actions_guarded: "Accept"
        }.merge(qualification_values_as_mturk(type, comp_hash)))
      else
        qualification
      end
     end

     def qualification_values_as_mturk(type, comp_hash)
      if type == :country
        {
          locale_values: [ Aws::MTurk::Types::Locale.new( country: comp_hash.values.first) ]
        }
      else 
        { integer_values: comp_hash.values }
      end
     end

     def create_hit(host, hit_title, hit_description, typ, num_assignments, reward, lifetime,
                        duration = nil, qualifications = {}, params = {}, opts = {})
      model = typ.to_s.constantize
      #HIT_FRAME_HEIGHT = 1000
      f_url = build_url(host, model, params, opts)
            external_question = <<-XML
      <ExternalQuestion xmlns="http://mechanicalturk.amazonaws.com/AWSMechanicalTurkDataSchemas/2006-07-14/ExternalQuestion.xsd">
        <ExternalURL>#{f_url}</ExternalURL>
        <FrameHeight>#{1000}</FrameHeight>
      </ExternalQuestion>
            XML
      handle_create_response mturk_client.create_hit({
        max_assignments: num_assignments,
        reward: sprintf('%.2f',reward),
        lifetime_in_seconds: lifetime.to_i.days.seconds.to_i,
        assignment_duration_in_seconds: duration.to_i.hours.seconds.to_i,
        title: hit_title,
        description: hit_description,
        question:  external_question,
        qualification_requirements: qualifications.to_a.map { |key, val| qualification_as_mturk(key, val) }

      })
    end

    def assignments_for_hit(hit_id)
      handle_assignment_responses mturk_client.list_assignments_for_hit(hit_id: hit_id).assignments
    end

    def approve_assignment(assignment_id, feedback='',override_rejection=false)
      mturk_client.approve_assignment({
        assignment_id: assignment_id,
        requester_feedback: feedback,
        override_rejection: override_rejection
      })
    end

    delegate :create_worker_block, :notify_workers, :delete_worker_block, :list_hits, to: :mturk_client

    def expire_hit(hit_id)
      mturk_client.update_expiration_for_hit({
        hit_id: hit_id,
        expire_at: Time.zone.now
      })
    end

    def delete_hit(hit_id)
      mturk_client.delete_hit(hit_id: hit_id)
    end

    def reject_assignment(assignment_id, feedback='Data not valid per requirements')
      mturk_client.reject_assignment({
        assignment_id: assignment_id,
        requester_feedback: feedback
      })
    end

    def worker_url_for_hit(hit_type_id)
      if TurkAPI.sandbox?
        "http://workersandbox.mturk.com/mturk/preview?groupId=#{hit_type_id}"
      else
        "http://mturk.com/mturk/preview?groupId=#{hit_type_id}"
      end
    end

    def handle_assignment_responses(responses)
      responses.map do |assignment_response|
        AnswerParser.new(assignment_response)
      end
    end

    def handle_create_response(response)
      {
        raw_hit: response.hit,
        hit_id: response.hit.hit_id,
        hit_url: worker_url_for_hit(response.hit.hit_type_id)
      }
    end

    # extracted from rturk
    # Copyright (c) 2009 Mark Percival

    # Permission is hereby granted, free of charge, to any person obtaining
    # a copy of this software and associated documentation files (the
    # "Software"), to deal in the Software without restriction, including
    # without limitation the rights to use, copy, modify, merge, publish,
    # distribute, sublicense, and/or sell copies of the Software, and to
    # permit persons to whom the Software is furnished to do so, subject to
    # the following conditions:

    # The above copyright notice and this permission notice shall be
    # included in all copies or substantial portions of the Software.

    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    # LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    # OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    # WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    class AnswerParser
      attr_reader :response

      delegate :assignment_id, :hit_id, :worker_id, :assignment_status, :accept_time,
               :submit_time, :approval_time, :rejection_time, :auto_approval_time, to: :response
      def initialize(response)
        @response = response
        @xml = response.answer
      end
      def normalized_answers
        normalize_nested_params answers
      end
      def answers
        answer_xml = Nokogiri::XML(@xml)
        answer_hash = {}
        answers = answer_xml.xpath('//xmlns:Answer')
        answers.each do |answer|
          key, value = nil, nil
          answer.children.each do |child|
            next if child.blank?
            if child.name == 'QuestionIdentifier'
              key = child.inner_text
            else
              value = child.inner_text
            end
          end
          answer_hash[key] = value
        end
        answer_hash
      end

      # Takes a Rails-like nested param hash and normalizes it.
      def normalize_nested_params(hash)
        new_hash = {}
        hash.each do |k,v|
          inner_hash = new_hash
          keys = k.split(/[\[\]]/).reject{|s| s.nil? || s.empty? }
          keys[0...keys.size-1].each do |key|
            inner_hash[key] ||= {}
            inner_hash = inner_hash[key]
          end
          inner_hash[keys.last] = v
        end
        new_hash
      end
    end
  end

end