package 
{
	import BaseAssets.BaseMain;
	import BaseAssets.events.BaseEvent;
	import BaseAssets.tutorial.CaixaTexto;
	import com.adobe.serialization.json.JSON;
	import cepa.utils.ToolTip;
	import com.eclecticdesignstudio.motion.Actuate;
	import com.eclecticdesignstudio.motion.easing.Linear;
	import fl.transitions.easing.None;
	import fl.transitions.Tween;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.filters.GlowFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.utils.Timer;
	import pipwerks.SCORM;
	
	/**
	 * ...
	 * @author Alexandre
	 */
	public class Main extends BaseMain
	{
		private var tweenTime:Number = 0.2;
		private var pecas:Array = [];
		private var fundos:Array = [];
		private var pecasWover:Array = [];
		private var fundosToSort:Array = [];
		
		override protected function init():void 
		{
			organizeLayers();
			addListeners();
			createAnswer();
			
			if (ExternalInterface.available) {
				initLMSConnection();
				if (mementoSerialized != null) {
					if(mementoSerialized != "" && mementoSerialized != "null") recoverStatus(mementoSerialized);
				}
			}
			
			if (connected) {
				if (scorm.get("cmi.entry") == "ab-initio") iniciaTutorial();
			}else {
				if (score == 0) iniciaTutorial();
			}
		}
		
		private function organizeLayers():void 
		{
			layerAtividade.addChild(setas);
			layerAtividade.addChild(entrada);
			layerAtividade.addChild(finaliza);
			
			for (var i:int = 0; i < numChildren; i++) 
			{
				var child:DisplayObject = getChildAt(i);
				if (child is Peca) {
					pecas.push(child);
				}else if (child is Fundo) {
					fundos.push(child);
					fundosToSort.push(child);
				}
			}
			
			for each (var fundo:Fundo in fundos) 
			{
				layerAtividade.addChild(fundo);
			}
			
			for each (var peca:Peca in pecas) 
			{
				layerAtividade.addChild(peca);
			}
		}
		
		private function addListeners():void 
		{
			finaliza.addEventListener(MouseEvent.CLICK, finalizaExec);
			finaliza.buttonMode = true;
		}
		
		private var wrongWcolor:Boolean = false;
		private function finalizaExec(e:MouseEvent):void 
		{
			if (checkForFinish()) {
				var nCertas:int = 0;
				var nPecas:int = 0;
				
				for each (var child:Peca in pecas) 
				{
					nPecas++;
					if(Peca(child).fundo.indexOf(Peca(child).currentFundo) != -1){
						nCertas++;
						trace(Peca(child).nome);
					}else {
						child.filters = [fundoFilter];
						wrongWcolor = true;
					}
				}
				
				var currentScore:Number = int((nCertas / nPecas) * 100);
				
				if (currentScore < 100) {
					feedbackScreen.setText("Ops!... \nReveja sua resposta.\nOs elementos destacados em vermelho estão incorretos.");
					completed = false;
				}
				else {
					feedbackScreen.setText("Parabéns!\nSua resposta está correta!");
					fixOverOut();
					travaPecas();
					completed = true;
				}
				
				//if (!completed) {
					//completed = true;
					score = currentScore;
					saveStatus();
					commit();
				//}
			}else {
				feedbackScreen.setText("Você precisa posicionar todas as peças antes de finalizar.");
			}
		}
		
		private function travaPecas():void 
		{
			for each (var child:Peca in pecas) 
			{
				Peca(child).lock();
			}
			
			//finaliza.mouseEnabled = false;
			//finaliza.alpha = 0.5;
			
			//botoes.resetButton.mouseEnabled = false;
			//botoes.resetButton.alpha = 0.5;
		}
		
		private function verificaFinaliza():void 
		{
			for each (var child:Peca in pecas) 			{
				if(Peca(child).currentFundo == null){
					finaliza.mouseEnabled = false;
					finaliza.alpha = 0.5;
					return;
				}
			}
			
			finaliza.mouseEnabled = true;
			finaliza.alpha = 1;
		}
		
		private function checkForFinish():Boolean
		{
			for each (var child:Peca in pecas)  {
				if (Peca(child).currentFundo == null) return false;
			}
			
			return true;
		}
		
		private function createAnswer():void 
		{
			for each (var child:Peca in pecas)  {
				setAnswerForPeca(Peca(child));
				var objClass:Class = Class(getDefinitionByName(getQualifiedClassName(child)));
				var ghostObj:* = new objClass();
				MovieClip(ghostObj).gotoAndStop(2);
				Peca(child).ghost = ghostObj;
				Peca(child).addListeners();
				//Peca(child).inicialPosition = new Point(child.x, child.y);
				child.addEventListener("paraArraste", verifyPosition);
				child.addEventListener("iniciaArraste", verifyForFilter);
				Peca(child).buttonMode = true;
				Peca(child).gotoAndStop(2);
			}
		}
		
		private function saveStatusForRecovery(e:MouseEvent = null):void
		{
			var status:Object = new Object();
			
			status.completed = completed;
			status.score = score;
			status.pecas = new Object();
			
			for each (var child:Peca in pecas)  {
				if (Peca(child).currentFundo != null) status.pecas[child.name] = Peca(child).currentFundo.name;
				else status.pecas[child.name] = "null";
			}
			
			mementoSerialized = JSON.encode(status);
		}
		
		private function recoverStatus(memento:String):void
		{
			var status:Object = JSON.decode(memento);
			
			for each (var child:Peca in pecas) {
				if (status.pecas[child.name] != "null") {
					Peca(child).currentFundo = getFundoByName(status.pecas[child.name]);
					Fundo(Peca(child).currentFundo).currentPeca = Peca(child);
					Peca(child).x = Peca(child).currentFundo.x;
					Peca(child).y = Peca(child).currentFundo.y;
					Peca(child).gotoAndStop(2);
				}
			}
			
			if (!connected) {
				completed = status.completed;
				score = status.score;
			}
			
			if (completed) {
				fixOverOut();
				travaPecas();
			}
		}
		
		private var pecaDragging:Peca;
		//private var fundoFilter:GlowFilter = new GlowFilter(0xFF0000, 1, 20, 20, 1, 2, true, true);
		private var fundoFilter:GlowFilter = new GlowFilter(0x800000);
		private var fundoWGlow:MovieClip;
		private function verifyForFilter(e:Event):void 
		{
			if (wrongWcolor) {
				for each (var item:Peca in pecas) 
				{
					item.filters = [];
				}
				wrongWcolor = false;
			}
			pecaDragging = Peca(e.target);
			
			var peca:Peca = pecaDragging;
			peca.removeEventListener(MouseEvent.MOUSE_OUT, outChid);
			
			if (peca.currentFundo != null) {
				if (peca.currentFundo is FundoComBorda) {
					Fundo(peca.currentFundo).fundo.graphics.clear();
				}
				peca.gotoAndStop(2);
				peca.currentFundo.scaleY = 1;
				//peca.currentFundo.height = alturaPecaOver;
				peca.currentFundo.y = peca.y;
				//peca.currentFundo.height = alturaPecaOver;
				if (peca.currentFundo is FundoComBorda) {
					drawBorder(Fundo(peca.currentFundo));
				}
			}else {
				peca.gotoAndStop(1);
			}
			
			stage.addEventListener(MouseEvent.MOUSE_MOVE, verifying);
		}
		
		private function verifying(e:MouseEvent):void 
		{
			var fundoUnder:Fundo = getFundo(new Point(pecaDragging.ghost.x, pecaDragging.ghost.y));
			
			if (fundoUnder != null) {
				/*if (fundoUnder.currentPeca != null) {
					if (fundoWGlow == null) {
						fundoWGlow = fundoUnder.currentPeca;
						fundoWGlow.gotoAndStop(2);
					}else {
						if (fundoWGlow is Fundo) {
							fundoWGlow.borda.filters = [];
						}else {
							fundoWGlow.gotoAndStop(1);
						}
						fundoWGlow = fundoUnder.currentPeca;
						fundoWGlow.gotoAndStop(2);
					}
				}else{*/
					if (fundoWGlow == null) {
						fundoWGlow = fundoUnder;
						fundoWGlow.borda.filters = [fundoFilter];
					}else {
						if (fundoWGlow is Fundo) {
							fundoWGlow.borda.filters = [];
						}else {
							fundoWGlow.gotoAndStop(1);
						}
						fundoWGlow = fundoUnder;
						fundoWGlow.borda.filters = [fundoFilter];
					}
				//}
			}else {
				if (fundoWGlow != null) {
					if(fundoWGlow is Fundo){
						Fundo(fundoWGlow).borda.filters = [];
					}else {
						fundoWGlow.gotoAndStop(1);
					}
					fundoWGlow = null;
				}
			}
		}
		
		private function verifyPosition(e:Event):void 
		{
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, verifying);
			pecaDragging = null;
			if (fundoWGlow != null) {
				if (fundoWGlow is Fundo) fundoWGlow.borda.filters = [];
				else fundoWGlow.gotoAndStop(1);
				fundoWGlow = null;
			}
			
			var peca:Peca = e.target as Peca;
			var fundoDrop:Fundo = getFundo(peca.position);
			
			if (fundoDrop != null) {
				if (fundoDrop.currentPeca == null) {
					if (peca.currentFundo != null) {
						Fundo(peca.currentFundo).currentPeca = null;
					}
					fundoDrop.currentPeca = peca;
					peca.currentFundo = fundoDrop;
					//tweenX = new Tween(peca, "x", None.easeNone, peca.x, fundoDrop.x, 0.5, true);
					//tweenY = new Tween(peca, "y", None.easeNone, peca.y, fundoDrop.y, 0.5, true);
					peca.x = fundoDrop.x;
					peca.y = fundoDrop.y;
					peca.gotoAndStop(2);
				}else {
					if(peca.currentFundo != null){
						var pecaFundo:Peca = Peca(fundoDrop.currentPeca);
						var fundoPeca:Fundo = Fundo(peca.currentFundo);
						
						Actuate.tween(peca, tweenTime, { x:fundoDrop.x, y:fundoDrop.y } ).ease(Linear.easeNone);
						//tweenX = new Tween(peca, "x", None.easeNone, peca.x, fundoDrop.x, tweenTime, true);
						//tweenY = new Tween(peca, "y", None.easeNone, peca.y, fundoDrop.y + 20, tweenTime, true);
						
						Actuate.tween(pecaFundo, tweenTime, { x:fundoPeca.x, y:fundoPeca.y} ).ease(Linear.easeNone);
						//tweenX2 = new Tween(pecaFundo, "x", None.easeNone, pecaFundo.x, fundoPeca.x, tweenTime, true);
						//tweenY2 = new Tween(pecaFundo, "y", None.easeNone, pecaFundo.y, fundoPeca.y + 20, tweenTime, true);
						
						peca.currentFundo = fundoDrop;
						fundoDrop.currentPeca = peca;
						
						pecaFundo.currentFundo = fundoPeca;
						fundoPeca.currentPeca = pecaFundo;
					}else {
						pecaFundo = Peca(fundoDrop.currentPeca);
						
						//tweenX = new Tween(peca, "x", None.easeNone, peca.position.x, fundoDrop.x, tweenTime, true);
						//tweenY = new Tween(peca, "y", None.easeNone, peca.position.y, fundoDrop.y, tweenTime, true);
						peca.x = fundoDrop.x;
						peca.y = fundoDrop.y;
						peca.gotoAndStop(2);
						
						Actuate.tween(pecaFundo, tweenTime, { x:pecaFundo.inicialPosition.x, y:pecaFundo.inicialPosition.y} ).ease(Linear.easeNone);
						//tweenX2 = new Tween(pecaFundo, "x", None.easeNone, pecaFundo.x, pecaFundo.inicialPosition.x, tweenTime, true);
						//tweenY2 = new Tween(pecaFundo, "y", None.easeNone, pecaFundo.y, pecaFundo.inicialPosition.y, tweenTime, true);
						
						peca.currentFundo = fundoDrop;
						fundoDrop.currentPeca = peca;
						
						pecaFundo.currentFundo = null;
						pecaFundo.gotoAndStop(1);
					}
				}
			}else {
				if (peca.currentFundo != null) {
					Fundo(peca.currentFundo).currentPeca = null;
					peca.currentFundo = null;
				}
				
				Actuate.tween(peca, tweenTime, { x:peca.inicialPosition.x, y:peca.inicialPosition.y} ).ease(Linear.easeNone);
				//tweenX = new Tween(peca, "x", None.easeNone, peca.x, peca.inicialPosition.x, tweenTime, true);
				//tweenY = new Tween(peca, "y", None.easeNone, peca.y, peca.inicialPosition.y, tweenTime, true);
				peca.gotoAndStop(1);
			}
			
			//verificaFinaliza();
			
			//setTimeout(saveStatus, (tweenTime + 0.1) * 1000);
			Actuate.timer(tweenTime + 0.1).onComplete(saveStatus);
		}
		
		private function getFundo(position:Point):Fundo 
		{
			for each (var child:Fundo in fundos)  {
				if (child.hitTestPoint(position.x, position.y)) return Fundo(child);
			}
			
			return null;
		}
		
		private function getFundoByName(name:String):Fundo 
		{
			if (name == "") return null;
			for each (var child:Fundo in fundos) {
				if (child.name == name) return Fundo(child);
			}
			
			return null;
		}
		
		private function setAnswerForPeca(child:Peca):void 
		{
			if (child is Peca1) {
				child.fundo = [fundo1];
				child.nome = "peca1";
			}else if (child is Peca2) {
				child.fundo = [fundo2];
				child.nome = "peca2";
			}else if (child is Peca3) {
				child.fundo = [fundo3];
				child.nome = "peca3";
			}else if (child is Peca4) {
				child.fundo = [fundo4];
				child.nome = "peca4";
			}else if (child is Peca5) {
				child.fundo = [fundo5];
				child.nome = "peca5";
			}else if (child is Peca6) {
				child.fundo = [fundo6];
				child.nome = "peca6";
			}else if (child is Peca7) {
				child.fundo = [fundo7];
				child.nome = "peca7";
			}else if (child is Peca8) {
				child.fundo = [fundo8];
				child.nome = "peca8";
			}else if (child is Peca9) {
				child.fundo = [fundo9];
				child.nome = "peca9";
			}else if (child is Peca10) {
				child.fundo = [fundo10];
				child.nome = "peca10";
			}else if (child is Peca11) {
				child.fundo = [fundo11];
				child.nome = "peca11";
			}else if (child is Peca12) {
				child.fundo = [fundo12];
				child.nome = "peca12";
			}else if (child is Peca13) {
				child.fundo = [fundo13];
				child.nome = "peca13";
			}else if (child is Peca14) {
				child.fundo = [fundo14];
				child.nome = "peca14";
			}else if (child is Peca15) {
				child.fundo = [fundo15];
				child.nome = "peca15";
			}else if (child is Peca16) {
				child.fundo = [fundo16];
				child.nome = "peca16";
			}else if (child is Peca17) {
				child.fundo = [fundo17];
				child.nome = "peca17";
			}else if (child is Peca18) {
				child.fundo = [fundo18];
				child.nome = "peca18";
			}else if (child is Peca19) {
				child.fundo = [fundo19];
				child.nome = "peca19";
			}else if (child is Peca20) {
				child.fundo = [fundo20];
				child.nome = "peca20";
			}
			
			randomizeInicialPosition(child);
			
			//pecasLayer.addChild(child);
		}
		
		private function randomizeInicialPosition(peca:Peca):void
		{
			var indexPeca:int = int(peca.nome.replace("peca", ""));
			
			var indexSort:int = Math.floor(Math.random() * fundosToSort.length);
			var indexFundo:int = int(fundosToSort[indexSort].name.replace("fundo", ""));
			
			while (indexPeca == indexFundo) {
				indexSort = Math.floor(Math.random() * fundosToSort.length);
				indexFundo = int(fundosToSort[indexSort].name.replace("fundo", ""));
			}
			
			var fundoInicial:Fundo = fundosToSort[indexSort];
			
			peca.inicialPosition = new Point(fundoInicial.x, fundoInicial.y);
			peca.x = fundoInicial.x;
			peca.y = fundoInicial.y;
			peca.currentFundo = fundoInicial;
			fundoInicial.currentPeca = peca;
			
			fundosToSort.splice(indexSort, 1);
		}
		
		private function makeOverOut(peca:MovieClip):void
		{
			peca.addEventListener(MouseEvent.MOUSE_OVER, overChid);
			//peca.addEventListener(MouseEvent.MOUSE_OUT, outChid);
			pecasWover.push(peca);
		}
		
		private function fixOverOut():void 
		{
			for each (var peca:Peca in pecasWover) 
			{
				peca.removeEventListener(MouseEvent.MOUSE_OVER, overChid);
				peca.removeEventListener(MouseEvent.MOUSE_OUT, outChid);
				
				if (peca.currentFundo is FundoComBorda) {
					Fundo(peca.currentFundo).fundo.graphics.clear();
				}
				var alturaAntes:Number = peca.height;
				peca.gotoAndStop(4);
				var alturaDepois:Number = peca.height;
				alturaPecaOver = peca.currentFundo.height;
				//peca.currentFundo.height = alturaPecaOver * (alturaDepois / alturaAntes);
				peca.currentFundo.scaleY = alturaDepois / alturaAntes;
				peca.currentFundo.y = peca.y + (alturaDepois - alturaAntes) / 2;
				if (peca.currentFundo is FundoComBorda) {
					drawBorder(Fundo(peca.currentFundo)/*, alturaDepois / alturaAntes*/);
				}
			}
		}
		
		private var alturaPecaOver:Number;
		private var borderRet:int = 2;
		private function overChid(e:MouseEvent):void
		{
			if (pecaDragging != null) return;
			
			var peca:Peca = Peca(e.target);
			peca.addEventListener(MouseEvent.MOUSE_OUT, outChid);
			
			if (peca.currentFundo != null) {
				if (peca.currentFundo is FundoComBorda) {
					Fundo(peca.currentFundo).fundo.graphics.clear();
				}
				var alturaAntes:Number = peca.height;
				peca.gotoAndStop(4);
				var alturaDepois:Number = peca.height;
				alturaPecaOver = peca.currentFundo.height;
				//peca.currentFundo.height = alturaPecaOver * (alturaDepois / alturaAntes);
				peca.currentFundo.scaleY = alturaDepois / alturaAntes;
				peca.currentFundo.y = peca.y + (alturaDepois - alturaAntes) / 2;
				if (peca.currentFundo is FundoComBorda) {
					drawBorder(Fundo(peca.currentFundo)/*, alturaDepois / alturaAntes*/);
				}
			}else {
				peca.gotoAndStop(3);
			}
		}
		
		private function drawBorder(fundo:Fundo, scale:Number = 1):void
		{
			fundo.fundo.graphics.clear();
			fundo.fundo.graphics.lineStyle(1, 0x000000);
			fundo.fundo.graphics.drawRect( (-fundo.width / 2 - borderRet), (-fundo.height / 2 - borderRet)/scale, (fundo.width + (2 * borderRet)), (fundo.height + (2 * borderRet)) / scale);
		}
		
		private function outChid(e:MouseEvent):void
		{
			var peca:Peca = Peca(e.target);
			peca.removeEventListener(MouseEvent.MOUSE_OUT, outChid);
			
			if (peca.currentFundo != null) {
				if (peca.currentFundo is FundoComBorda) {
					Fundo(peca.currentFundo).fundo.graphics.clear();
				}
				peca.gotoAndStop(2);
				peca.currentFundo.scaleY = 1;
				//peca.currentFundo.height = alturaPecaOver;
				peca.currentFundo.y = peca.y;
				//peca.currentFundo.height = alturaPecaOver;
				if (peca.currentFundo is FundoComBorda) {
					drawBorder(Fundo(peca.currentFundo));
				}
			}else {
				peca.gotoAndStop(1);
			}
		}
		
		override public function reset(e:MouseEvent = null):void
		{
			if(connected){
				if (completed) return;
			}else {
				if (completed) completed = false;
				score = 0;
			}
			
			wrongWcolor = false;
			
			for each (var item:Fundo in fundos) 
			{
				fundosToSort.push(item);
			}
			
			for each (var child:Peca in pecas)  {
				child.filters = [];
				randomizeInicialPosition(child);
			}
			
			//verificaFinaliza();
			saveStatus();
		}
		
		
		//---------------- Tutorial -----------------------
		
		private var balao:CaixaTexto;
		private var pointsTuto:Array;
		private var tutoBaloonPos:Array;
		private var tutoPos:int;
		private var tutoSequence:Array = [	"Veja aqui as orientações.",
											"Arraste os conceitos e termos de ligação...", 
											"... para os campos corretos.",
											"Pressione \"terminei\" para avaliar sua resposta."];
		
		override public function iniciaTutorial(e:MouseEvent = null):void  
		{
			blockAI();
			
			tutoPos = 0;
			if(balao == null){
				balao = new CaixaTexto();
				layerTuto.addChild(balao);
				balao.visible = false;
				
				pointsTuto = 	[new Point(590, 505),
								new Point(355 , 476),
								new Point(325 , 210),
								new Point(finaliza.x, finaliza.y + finaliza.height / 2)];
								
				tutoBaloonPos = [[CaixaTexto.RIGHT, CaixaTexto.FIRST],
								[CaixaTexto.BOTTON, CaixaTexto.CENTER],
								[CaixaTexto.TOP, CaixaTexto.CENTER],
								[CaixaTexto.TOP, CaixaTexto.FIRST]];
			}
			balao.removeEventListener(BaseEvent.NEXT_BALAO, closeBalao);
			
			balao.setText(tutoSequence[tutoPos], tutoBaloonPos[tutoPos][0], tutoBaloonPos[tutoPos][1]);
			balao.setPosition(pointsTuto[tutoPos].x, pointsTuto[tutoPos].y);
			balao.addEventListener(BaseEvent.NEXT_BALAO, closeBalao);
			balao.addEventListener(BaseEvent.CLOSE_BALAO, iniciaAi);
		}
		
		private function closeBalao(e:Event):void 
		{
			tutoPos++;
			if (tutoPos >= tutoSequence.length) {
				balao.removeEventListener(BaseEvent.NEXT_BALAO, closeBalao);
				balao.visible = false;
				iniciaAi(null);
			}else {
				balao.setText(tutoSequence[tutoPos], tutoBaloonPos[tutoPos][0], tutoBaloonPos[tutoPos][1]);
				balao.setPosition(pointsTuto[tutoPos].x, pointsTuto[tutoPos].y);
			}
		}
		
		private function iniciaAi(e:BaseEvent):void 
		{
			balao.removeEventListener(BaseEvent.CLOSE_BALAO, iniciaAi);
			balao.removeEventListener(BaseEvent.NEXT_BALAO, closeBalao);
			unblockAI();
		}
		
		
		/*------------------------------------------------------------------------------------------------*/
		//SCORM:
		
		private const PING_INTERVAL:Number = 5 * 60 * 1000; // 5 minutos
		private var completed:Boolean;
		private var scorm:SCORM;
		private var scormExercise:int;
		private var connected:Boolean;
		private var score:int = 0;
		private var pingTimer:Timer;
		private var mementoSerialized:String = "";
		
		/**
		 * @private
		 * Inicia a conexão com o LMS.
		 */
		private function initLMSConnection () : void
		{
			completed = false;
			connected = false;
			scorm = new SCORM();
			
			pingTimer = new Timer(PING_INTERVAL);
			pingTimer.addEventListener(TimerEvent.TIMER, pingLMS);
			
			connected = scorm.connect();
			
			if (connected) {
				
				if (scorm.get("cmi.mode" != "normal")) return;
				
				scorm.set("cmi.exit", "suspend");
				// Verifica se a AI já foi concluída.
				var status:String = scorm.get("cmi.completion_status");	
				mementoSerialized = scorm.get("cmi.suspend_data");
				var stringScore:String = scorm.get("cmi.score.raw");
				
				switch(status)
				{
					// Primeiro acesso à AI
					case "not attempted":
					case "unknown":
					default:
						completed = false;
						break;
					
					// Continuando a AI...
					case "incomplete":
						completed = false;
						break;
					
					// A AI já foi completada.
					case "completed":
						completed = true;
						//setMessage("ATENÇÃO: esta Atividade Interativa já foi completada. Você pode refazê-la quantas vezes quiser, mas não valerá nota.");
						break;
				}
				
				//unmarshalObjects(mementoSerialized);
				scormExercise = 1;
				score = Number(stringScore.replace(",", "."));
				
				var success:Boolean = scorm.set("cmi.score.min", "0");
				if (success) success = scorm.set("cmi.score.max", "100");
				
				if (success)
				{
					scorm.save();
					pingTimer.start();
				}
				else
				{
					//trace("Falha ao enviar dados para o LMS.");
					connected = false;
				}
			}
			else
			{
				trace("Esta Atividade Interativa não está conectada a um LMS: seu aproveitamento nela NÃO será salvo.");
				mementoSerialized = ExternalInterface.call("getLocalStorageString");
			}
			
			//reset();
		}
		
		/**
		 * @private
		 * Salva cmi.score.raw, cmi.location e cmi.completion_status no LMS
		 */ 
		private function commit()
		{
			if (connected)
			{
				if (scorm.get("cmi.mode" != "normal")) return;
				
				// Salva no LMS a nota do aluno.
				var success:Boolean = scorm.set("cmi.score.raw", score.toString());

				// Notifica o LMS que esta atividade foi concluída.
				success = scorm.set("cmi.completion_status", (completed ? "completed" : "incomplete"));

				// Salva no LMS o exercício que deve ser exibido quando a AI for acessada novamente.
				success = scorm.set("cmi.location", scormExercise.toString());
				
				// Salva no LMS a string que representa a situação atual da AI para ser recuperada posteriormente.
				//mementoSerialized = marshalObjects();
				success = scorm.set("cmi.suspend_data", mementoSerialized.toString());
				
				if (score > 99) success = scorm.set("cmi.success_status", "passed");
				else success = scorm.set("cmi.success_status", "failed");

				if (success)
				{
					scorm.save();
				}
				else
				{
					pingTimer.stop();
					//setMessage("Falha na conexão com o LMS.");
					connected = false;
				}
			}else { //LocalStorage
				ExternalInterface.call("save2LS", mementoSerialized);
			}
		}
		
		/**
		 * @private
		 * Mantém a conexão com LMS ativa, atualizando a variável cmi.session_time
		 */
		private function pingLMS (event:TimerEvent)
		{
			//scorm.get("cmi.completion_status");
			commit();
		}
		
		private function saveStatus(e:Event = null):void
		{
			if (ExternalInterface.available) {
				if (connected) {
					
					if (scorm.get("cmi.mode" != "normal")) return;
					
					saveStatusForRecovery();
					scorm.set("cmi.suspend_data", mementoSerialized);
					commit();
				}else {//LocalStorage
					saveStatusForRecovery();
					ExternalInterface.call("save2LS", mementoSerialized);
				}
			}
		}
		
	}

}