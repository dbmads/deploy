from flask import request,render_template,sessions,jsonify,flash,redirect,url_for
from flask.ext.classy import FlaskView

from app import app
from model import Visitor,Prospect,Order,Response
from limelight.api import TransactionClient
import flask
default_campaign="55"
api = "https://www.securetotaloffers.com"
username = "rhinoxapi"
password = "76dqJuvjMJHXT"
country = 'US'
class IndexView(FlaskView):

    def get(self):

        params=['s1','s2','s3','s4','s5','affid','sid','campaign_id']
        url_params = {}
        url_params['ip_address'] = request.remote_addr
        url_params['lander_url'] = request.url
        url_params['device_type'] = str(request.user_agent)
        url_params['next']="checkout"

        if request.args.get('campaign_id')=="":
            url_params['campaign_id'] = default_campaign
        try:
            get_params = request.args.items()
            z = get_params.copy()
            url_params.update(z)
            visitor = Visitor.create(**url_params)
            url_params['click_id'] = visitor.click_id
        except:
            pass
        return render_template('index.html', url_params=url_params)
    '''def post(self):
        params = ['firstName','lastName','address1','postalCode','city','state','country','email','phone','campaignId','js_ok']
        for x in params:
            try:
                url_params[x]=request.form['x']
            except:
                pass
        return render_template('index.html', params=params)'''
    def post(self):
        return redirect(url_for('ProspectView'))



class ProspectView(FlaskView):


    def post(self):
        prospect_curl   = TransactionClient(api,username = username , password = password)
        post_data = request.form.items()
        response = prospect_curl.NewProspect(**post_data)
        if response.errorMessage==1:
            visitor_id  = request.form['click_id']
            response = Response()
            response.prospect= int(visitor_id)
            response.response_object =  response.__dict__
            response.save()
            form_data = {}
            form_data['result']="ERROR"
            form_data['error_message']=prospect_curl.error_message
            return jsonify(form_data)
        else:
            prospect_id = response.prospectId
            form_data = {}
            form_data['result']="SUCCESS"
            form_data['prospect_id'] = prospect_id
            form_data['campaign_id'] = post_data['campaign_id']
            form_data['click_id'] = post_data['click_id']
            params=['s1','s2','s3','s4','s5','affid','sid','campaign_id']
            for par in params:
                form_data[par]= post_data[par]
            return jsonify(form_data)

    def get(self):
        return "<html><head></head><body>Worked</body></html>"


IndexView.register(app, route_base="/")
ProspectView.register(app, route_base="/prospect")

#IndexView.register(app, route_base="/checkout/")
#IndexView.register(app, route_base="/upsell/1/")
#IndexView.register(app, route_base="/upsell/2/")
#IndexView.register(app, route_base="/upsell/3/")






if __name__ == '__main__':
    app.run(debug=True)
