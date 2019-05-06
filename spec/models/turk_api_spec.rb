require 'spec_helper'

describe Turkee::TurkAPI do
  let(:turk_api) { Turkee::TurkAPI.new }
  let(:aws_assignments_responses) {  YAML.load("---\n- !ruby/struct:Aws::MTurk::Types::Assignment\n  assignment_id: 3IQ1VMJRYTJZT98EKWXXXXXXXXX\n  worker_id: A1XXXXXXXXXXXXX\n  hit_id: 3HXCEECSQLSC8YR0EY00000000000\n  assignment_status: Submitted\n  auto_approval_time: 2019-06-02 14:16:37.000000000 -04:00\n  accept_time: 2019-05-03 14:14:48.000000000 -04:00\n  submit_time: 2019-05-03 14:16:37.000000000 -04:00\n  approval_time: \n  rejection_time: \n  deadline: \n  answer: |-\n    <?xml version=\"1.0\" encoding=\"ASCII\"?>\n    <QuestionFormAnswers xmlns=\"http://mechanicalturk.amazonaws.com/AWSMechanicalTurkDataSchemas/2005-10-01/QuestionFormAnswers.xsd\">\n      <Answer>\n        <QuestionIdentifier>utf8</QuestionIdentifier>\n        <FreeText>&#10003;</FreeText>\n      </Answer>\n      <Answer>\n        <QuestionIdentifier>authenticity_token</QuestionIdentifier>\n        <FreeText>XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/xxxxxxxxxxxxxxxxxxxxxxxxxxx+VOgrTA50xUNF6rBA==</FreeText>\n      </Answer>\n      <Answer>\n        <QuestionIdentifier>workerId</QuestionIdentifier>\n        <FreeText>A11111111111111</FreeText>\n      </Answer>\n      <Answer>\n        <QuestionIdentifier>turkSubmitTo</QuestionIdentifier>\n        <FreeText>https://workersandbox.mturk.com</FreeText>\n      </Answer>\n      <Answer>\n        <QuestionIdentifier>survey_id</QuestionIdentifier>\n        <FreeText>91</FreeText>\n      </Answer>\n      <Answer>\n        <QuestionIdentifier>response[survey_id]</QuestionIdentifier>\n        <FreeText>91</FreeText>\n      </Answer>\n      <Answer>\n        <QuestionIdentifier>response[answer]</QuestionIdentifier>\n        <FreeText>Pretty\n        Whiteboard Picture</FreeText>\n      </Answer>\n      <Answer>\n        <QuestionIdentifier>button</QuestionIdentifier>\n        <FreeText/>\n      </Answer>\n    </QuestionFormAnswers>\n  requester_feedback: \n") }
  let(:assignment_responses) {
    turk_api.handle_assignment_responses(aws_assignments_responses)
  }
  before(:each) do
    Turkee::TurkAPI.setup('key', 'pass', sandbox: true)
  end
  it 'should respond with answers to assignments' do
    expect(assignment_responses.first.normalized_answers['response']['answer']).to eq("Pretty\n    Whiteboard Picture")
  end
end