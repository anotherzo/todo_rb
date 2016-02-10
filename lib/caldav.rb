require 'net/https'
require 'rubygems'
require 'uuid'
require 'rexml/document'
require 'rexml/xpath'
require 'date'

class Event
    attr_accessor :uid, :created, :dtstart, :dtend, :lastmodified, :summary
end

class Todo
    attr_accessor :uid, :created, :summary, :dtstart, :status, :completed, :lastmodified, :sortorder

    def initialize
      @sortorder = '1'
    end

    def to_s
      @summary 
    end

    def completed?
      if @completed
        "(done)"
      end
    end
end

module Net
    class HTTP
        class Report < HTTPRequest
            METHOD = 'REPORT'
            REQUEST_HAS_BODY = true
            RESPONSE_HAS_BODY = true
        end
    end
end

class Caldav
    attr_accessor :host, :port, :url, :user, :password

    def initialize( conf, url )
       @host = conf['host']
       @port = conf['port']
       @user = conf['user']
       @password = conf['passwd']
       @url = url
    end

    def report start, stop
        dings = """<?xml version='1.0'?>
<c:calendar-query xmlns:c='urn:ietf:params:xml:ns:caldav'>
  <d:prop xmlns:d='DAV:'>
    <d:getetag/>
    <c:calendar-data>
    </c:calendar-data>
  </d:prop>
  <c:filter>
    <c:comp-filter name='VCALENDAR'>
      <c:comp-filter name='VEVENT'>
        <c:time-range start='#{start}Z' end='#{stop}Z'/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>
"""
        res = nil
        http = Net::HTTP.new(@host, @port)

        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = '/etc/ssl/zoserver.org.crt'
        
        http.start {|http|

            req = Net::HTTP::Report.new(@url, initheader = {'Content-Type'=>'application/xml', 'Depth' => '1'} )
            req.basic_auth @user, @password
            req.body = dings


            res = http.request( req )
        }
        result = []
        xml = REXML::Document.new( res.body )
        REXML::XPath.each( xml, '//c:calendar-data/', { "c"=>"urn:ietf:params:xml:ns:caldav"} ){ |c|
            result <<  parseVcal( c.text )
        }
        return result
    end
    
    def get uuid
        res = nil
        Net::HTTP.start( @host, @port ) {|http|
            req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
            req.basic_auth @user, @password
            res = http.request( req )
        }
        return parseVcal( res.body )
    end

    def delete uuid
        http = Net::HTTP.new @host, @port  
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = '/etc/ssl/zoserver.org.crt'
        http.start {|http|
            req = Net::HTTP::Delete.new("#{@url}/#{uuid}.ics")
          req.basic_auth @user, @password
            res = http.request( req )
        }
    end

    def create event
        now = DateTime.now 
        nowstr = now.strftime "%Y%m%dT%H%M%SZ"
        uuid_generator =  UUID.new
        uuid = uuid_generator.generate

     dings = """BEGIN:VCALENDAR
PRODID:Caldav.rb
VERSION:2.0
BEGIN:VEVENT
CREATED:#{nowstr}
UID:#{uuid}
SUMMARY:#{event.summary}
DTSTART:#{event.dtstart.strftime("%Y%m%dT%H%M%S")}
DTEND:#{event.dtend.strftime("%Y%m%dT%H%M%S")}
END:VEVENT
END:VCALENDAR"""



        res = nil
        http = Net::HTTP.new(@host, @port) 
        req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics")
        req['Content-Type'] = 'text/calendar'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = '/etc/ssl/zoserver.org.crt'
        req.basic_auth @user, @password
        req.body = dings
        res = http.request( req )
        puts @user, @password, @url, @host, @port, dings
        return uuid, res
    end

    def update event
        dings = """BEGIN:VCALENDAR
PRODID:Caldav.rb
VERSION:2.0

BEGIN:VTIMEZONE
TZID:/Europe/Vienna
X-LIC-LOCATION:Europe/Vienna
BEGIN:DAYLIGHT
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
TZNAME:CEST
DTSTART:19700329T020000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
TZNAME:CET
DTSTART:19701025T030000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10
END:STANDARD
END:VTIMEZONE

BEGIN:VEVENT
CREATED:#{event.created}
UID:#{event.uid}
SUMMARY:#{event.summary}
DTSTART;TZID=Europe/Vienna:#{event.dtstart}
DTEND;TZID=Europe/Vienna:#{event.dtend.rfc3339}
END:VEVENT
END:VCALENDAR"""

        res = nil
       
        http = Net::HTTP.new(@host, @port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = '/etc/ssl/zoserver.org.crt'
        
        http.start {|http|
            req = Net::HTTP::Put.new("#{@url}/#{event.uid}.ics", initheader = {'Content-Type'=>'text/calendar', 'Depth'=>'1'} )
            req.basic_auth @user, @passowrd
            req.body = dings
            res = http.request( req )
        }
        return event.uid
    end

    def todo 
        dings = """<?xml version='1.0'?>
<c:calendar-query xmlns:c='urn:ietf:params:xml:ns:caldav'>
  <d:prop xmlns:d='DAV:'>
    <d:getetag/>
    <c:calendar-data>
    </c:calendar-data>
  </d:prop>
  <c:filter>
    <c:comp-filter name='VCALENDAR'>
      <c:comp-filter name='VTODO'>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>
"""
        res = nil
        http = Net::HTTP.new(@host, @port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = '/etc/ssl/zoserver.org.crt'
        http.start {|http|
            req = Net::HTTP::Report.new(@url, initheader = {'Content-Type'=>'application/xml', 'Depth'=>'1'} )
            req.basic_auth @user, @password
            req.body = dings
            res = http.request( req )
        }
        result = []
        xml = REXML::Document.new( res.body )
        REXML::XPath.each( xml, '//cal:calendar-data/', { "cal"=>"urn:ietf:params:xml:ns:caldav"} ){ |c|
            result << parseVcal( c.text )
        }
        return result
    end

    def createTodo todo
        nowstr = Time.now.strftime "%Y%m%dT%H%M%SZ"
        uuid_generator =  UUID.new
        uuid = uuid_generator.generate

     dings = """BEGIN:VCALENDAR
PRODID:Caldav.rb
VERSION:2.0
BEGIN:VTODO
CREATED:#{nowstr}
UID:#{uuid}
SUMMARY:#{todo.summary}
END:VTODO
END:VCALENDAR"""



        res = nil
        http = Net::HTTP.new(@host, @port) 
        req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics")
        req['Content-Type'] = 'text/calendar'
        http.use_ssl = true
        
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = '/etc/ssl/zoserver.org.crt'
        req.basic_auth @user, @password
        req.body = dings
        res = http.request( req )
        #puts @user, @password, @url, @host, @port, dings
        return uuid, res
    end


    def parseVcal( vcal )
        if vcal.index( "VEVENT" ) then
            e = Event.new
            data = filterTimezone( vcal )
            data.split("\n").each{ |l|
                e.uid = getField( "UID:", l) if l =~ /UID/
                e.created = getField( "CREATED:", l) if l =~ /CREATED/
                e.dtstart = getField( "DTSTART", l) if l =~ /DTSTART/
                e.dtend = getField( "DTEND", l) if l =~ /DTEND/
                e.lastmodified = getField( "LAST-MODIFIED:", l) if l =~ /LAST-MODIFIED/
                e.summary = getField( "SUMMARY", l) if l =~ /SUMMARY/
            }
            return e
        elsif vcal.index( "VTODO" ) then 
            e = Todo.new
            vcal.gsub! /\n\ /, ''
            vcal.split("\n").each{ |l|
                e.uid = getField( "UID:", l ) if l =~ /UID:/
                e.created = getField( "CREATED:", l) if l =~ /CREATED:/
                e.dtstart = getField( "DTSTAMP:", l) if l =~ /DTSTAMP:/
                e.lastmodified = getField( "LAST-MODIFIED:", l) if l =~ /LAST-MODIFIED:/
                e.summary = getField( "SUMMARY:", l) if l =~ /SUMMARY:/
                e.status = getField( "STATUS:", l) if l =~ /STATUS:/
                e.completed = getField( "COMPLETED:", l) if l =~ /COMPLETED:/
                e.sortorder = getField( "X-APPLE-SORT-ORDER:", l) if l =~ /X-APPLE-SORT-ORDER:/
            }
            return e
        end
    end
    
    def filterTimezone( vcal )
        data = ""
        inTZ = false
        vcal.split("\n").each{ |l| 
            inTZ = true if l.index("BEGIN:VTIMEZONE") 
            data << l+"\n" unless inTZ 
            inTZ = false if l.index("END:VTIMEZONE") 
        }
        return data
    end

    def getField( name, l )
        fname = (name[-1] == ':'[0]) ? name[0..-2] : name 
        return NIL unless l.index(fname)
        idx = l.index( ":", l.index(fname))
        return l[ idx+1..-1 ] 
    end
end
