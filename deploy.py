from flask import request,render_template,sessions,jsonify,flash,redirect,url_for
from flask.ext.classy import FlaskView
import flask
app = flask(__name__,template_folder="templates")

class IndexView(FlaskView):

    def get(self):

        params=['s1','s2','s3','s4','s5','affid','sid','campaign_id']
        return "<html></head>"
    def post(self):
         return "<html></head>"


IndexView.register(app, route_base="/")

app.run(debug=True)
